SOPS_FILE := "../nix-secrets/.sops.yaml"

# Define path to helpers
export HELPERS_PATH := justfile_directory() + "/scripts/helpers.sh"

# List available commands
default:
  @just --list

# Temporarily track the flake.lock with git to satisfy nix commands
git-dance-pre:
    @git add --intent-to-add -f flake.lock
    @git update-index --assume-unchanged flake.lock

# Remove the flake.lock from git tracking
git-dance-post:
    @git rm --cached flake.lock || true

# Update commonly changing flakes and prep for a rebuild
rebuild-pre HOST=`hostname`: git-dance-pre update-nix-secrets
	nix flake update nixvim-flake --timeout 5 --reference-lock-file locks/{{HOST}}.lock
	@git add --intent-to-add .

# Run post-rebuild checks, like if sops is running properly afterwards
rebuild-post: git-dance-post check-sops


# Run a flake check on the config and installer
check HOST=`hostname` ARGS="":
	NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check --impure --keep-going --show-trace --reference-lock-file 	locks/{{HOST}}.lock {{ARGS}}
	cd nixos-installer && NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check --impure --keep-going --show-trace {{ARGS}}

# Rebuild the system
rebuild HOST=`hostname`: && rebuild-post
    @just rebuild-pre {{HOST}}
    @# NOTE: Add --option eval-cache false if you end up caching a failure you cant get around
    @scripts/rebuild.sh
    just rebuild-extensions-lite

# Rebuild the system and run a flake check
rebuild-full HOST=`hostname`: && rebuild-post
    @just rebuild-pre {{HOST}}
    scripts/rebuild.sh
    just check {{HOST}}
    just rebuild-extensions

# Rebuild the system with tshow trace
rebuild-trace: rebuild-pre && rebuild-post
	scripts/rebuild.sh trace
	just rebuild-extensions-lite

# Update all flake inputs for the specified host or the current host if none specified
update HOST=`hostname`:
	nix flake update --reference-lock-file locks/{{HOST}}.lock

# Update and then rebuild
rebuild-update: update rebuild

# Generate a new age key
age-key:
	nix-shell -p age --run "age-keygen"

# Check if sops-nix activated successfully
check-sops:
	scripts/check-sops.sh

# Update nix-secrets flake
update-nix-secrets HOST=`hostname`:
	@(cd ../nix-secrets && git fetch && git rebase > /dev/null) || true
	nix flake update nix-secrets --timeout 5 --reference-lock-file locks/{{HOST}}.lock

# Rebuild vscode extensions that update regularly
rebuild-extensions:
	scripts/build-vscode-extensions.sh || true

# Install vscode extensions, but don't rebuild
rebuild-extensions-lite:
	scripts/build-vscode-extensions.sh lite || true

# Build an iso image for installing new systems and create a symlink for qemu usage
iso HOST:
	# If we dont remove this folder, libvirtd VM doesnt run with the new iso
	rm -rf result
	nix build --impure .#nixosConfigurations.iso.config.system.build.isoImage --reference-lock-file locks/{{HOST}}.lock && ln -sf result/iso/*.iso latest_{{HOST}}.iso

# Install the latest iso to a flash drive
iso-install DRIVE HOST=`hostname`:
    just iso {{HOST}}
    sudo dd if=$(eza --sort changed result/iso/*.iso | tail -n1) of={{DRIVE}} bs=4M status=progress oflag=sync

# Configure a drive password using disko
disko DRIVE PASSWORD:
	echo "{{PASSWORD}}" > /tmp/disko-password
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
		--mode disko \
		hosts/common/disks/btrfs-luks-impermanence-disko.nix \
		--arg disk '"{{DRIVE}}"' \
		--arg password '"{{PASSWORD}}"'
	rm /tmp/disko-password

# Copy all the config files to the remote host
sync USER HOST PATH:
	rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}} -oport=10022" . {{USER}}@{{HOST}}:{{PATH}}/nix-config

# Run nixos-rebuild on the remote host
build-host HOST:
	NIX_SSHOPTS="-p10022" nixos-rebuild --target-host {{HOST}} --use-remote-sudo --show-trace --impure --flake .#"{{HOST}}" switch

#
# ========== Nix-Secrets manipulation recipes ==========
#

# Update sops keys in nix-secrets repo
sops-rekey:
  cd ../nix-secrets && for file in $(ls sops/*.yaml); do \
    sops updatekeys -y $file; \
  done

# Update all keys in sops/*.yaml files in nix-secrets to match the creation rules keys
rekey: sops-rekey
  cd ../nix-secrets && \
    (pre-commit run --all-files || true) && \
    git add -u && (git commit -nm "chore: rekey" || true) && git push

# Update an age key anchor or add a new one
sops-update-age-key FIELD KEYNAME KEY:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_update_age_key {{FIELD}} {{KEYNAME}} {{KEY}}

# Update an existing user age key anchor or add a new one
sops-update-user-age-key USER HOST KEY:
  just sops-update-age-key users {{USER}}_{{HOST}} {{KEY}}

# Update an existing host age key anchor or add a new one
sops-update-host-age-key HOST KEY:
  just sops-update-age-key hosts {{HOST}} {{KEY}}

# Automatically create creation rules entries for a <host>.yaml file for host-specific secrets
sops-add-host-creation-rules USER HOST:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_add_host_creation_rules "{{USER}}" "{{HOST}}"

# Automatically create creation rules entries for a shared.yaml file for shared secrets
sops-add-shared-creation-rules USER HOST:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_add_shared_creation_rules "{{USER}}" "{{HOST}}"

# Automatically add the host and user keys to creation rules for shared.yaml and <host>.yaml
sops-add-creation-rules USER HOST:
    just sops-add-host-creation-rules {{USER}} {{HOST}} && \
    just sops-add-shared-creation-rules {{USER}} {{HOST}}

#
# ========== Talon recipes ==========
#

# Add a talon beta linux URL hash to talon-versions.json
talon-linux URL:
  just talon linux {{URL}}

# Add a talon beta darwin URL hash to talon-versions.json
talon-darwin URL:
  just talon darwin {{URL}}

# Automatically add a new talon version to the talon-versions.json file
talon OS URL:
  cd ../nix-secrets && \
  if grep {{URL}} talon-versions.json; then \
    echo "URL already exists in talon-versions.json"; \
    exit 1; \
  fi && \
  sha256=$(nix-prefetch-url --unpack {{URL}}) && \
  jq --arg url "{{URL}}" \
     --arg sha "$sha256" \
     '.["talon-{{OS}}-beta"] = {"url": $url, "sha256": ("sha256:" + $sha)}' \
     talon-versions.json > temp.json && \
  mv temp.json talon-versions.json && \
  git add talon-versions.json && \
  git commit -nm "chore: update talon-{{OS}}-beta" && \
  git push

#
# ========= Admin Recipes ==========
#

# Create a new user with a password hash for dovecot, to be placed in ooze.yaml secrets
dovecot-hash:
    touch /tmp/empty-dovecot.conf
    DOVECONF=/dev/null nix shell nixpkgs#dovecot.out -c doveadm -c /tmp/empty-dovecot.conf pw -s SHA512-CRYPT
