SOPS_FILE := "../nix-secrets/.sops.yaml"

# Define path to helpers
export HELPERS_PATH := justfile_directory() + "/scripts/helpers.sh"


[private]
default:
  @just --list

[private]
copy-lock-in HOST=`hostname`:
    @mkdir -p locks
    @cp locks/{{HOST}}.lock flake.lock || true
    @git add --intent-to-add -f flake.lock
    @git update-index --assume-unchanged flake.lock

[private]
copy-lock-out HOST=`hostname`:
    @mkdir -p locks
    @cp flake.lock locks/{{HOST}}.lock
    @git rm --cached -f flake.lock > /dev/null || true
    @rm flake.lock || true

# Update commonly changing flakes and prep for a rebuild
[private]
rebuild-pre HOST=`hostname`:
    just update-nix-secrets {{HOST}} && \
    just update-nix-assets {{HOST}} && \
    just update-neovim-flake {{HOST}}
    @git add --intent-to-add .


# Run post-rebuild checks, like if sops is running properly afterwards
[private]
rebuild-post: check-sops

# Run a flake check on the config and installer
[group("checks")]
check HOST=`hostname` ARGS="":
    NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check --impure --keep-going --show-trace{{ARGS}}
    cd nixos-installer && NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check --impure --keep-going --show-trace {{ARGS}}

[private]
_rebuild HOST=`hostname`:
    @just rebuild-pre {{HOST}}
    @# NOTE: Add --option eval-cache false if you end up caching a failure you cant get around
    @just copy-lock-in {{HOST}}
    @scripts/rebuild.sh {{HOST}}
    @just copy-lock-out {{HOST}}

# Rebuild the system
[group("building")]
rebuild HOST=`hostname`: && rebuild-post
    @just _rebuild {{HOST}}
    just rebuild-extensions-lite

# Rebuild the system and run a flake check
[group("building")]
rebuild-full HOST=`hostname`: && rebuild-post
    @just _rebuild {{HOST}}
    just check {{HOST}}
    just rebuild-extensions

# Rebuild the system with tshow trace
#ebuild-trace: rebuild-pre && rebuild-post
#scripts/rebuild.sh trace
#	just rebuild-extensions-lite

# Update all flake inputs for the specified host or the current host if none specified
[group("update")]
update HOST=`hostname` *INPUT:
    @just copy-lock-in {{HOST}}
    nix flake update {{INPUT}} --timeout 5
    @just copy-lock-out {{HOST}}

# Update and then rebuild
[group("building")]
rebuild-update: update rebuild

# Generate a new age key
[group("secrets")]
age-key:
	nix-shell -p age --run "age-keygen"

# Check if sops-nix activated successfully
[group("checks")]
check-sops:
	scripts/check-sops.sh

# Update nix-secrets flake
[group("update")]
update-nix-secrets HOST=`hostname`:
	@(cd ../nix-secrets 2>/dev/null && git fetch && git rebase > /dev/null || echo "Push your nix-secrets changes") || true
	@just update {{HOST}} nix-secrets

# Update nix-assets
[group("update")]
update-nix-assets HOST=`hostname`:
    @just update {{HOST}} nix-assets

# Update neovim flake
[group("update")]
update-neovim-flake HOST=`hostname`:
    @just update {{HOST}} nixcats-flake

# Rebuild vscode extensions that update regularly
[group("building")]
rebuild-extensions:
	scripts/build-vscode-extensions.sh || true

# Install vscode extensions, but don't rebuild
[group("building")]
rebuild-extensions-lite:
	scripts/build-vscode-extensions.sh lite || true

# Build an iso image for installing new systems and create a symlink for qemu usage
[group("building")]
iso HOST:
	# If we dont remove this folder, libvirtd VM doesnt run with the new iso
	rm -rf result
	nix build --impure .#nixosConfigurations.iso.config.system.build.isoImage --reference-lock-file locks/{{HOST}}.lock && ln -sf result/iso/*.iso latest_{{HOST}}.iso

# Install the latest iso to a flash drive
[group("building")]
iso-install DRIVE HOST=`hostname`:
    just iso {{HOST}}
    sudo dd if=$(eza --sort changed result/iso/*.iso | tail -n1) of={{DRIVE}} bs=4M status=progress oflag=sync

# Configure a drive password using disko
[group("misc")]
disko DRIVE PASSWORD:
	echo "{{PASSWORD}}" > /tmp/disko-password
	sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
		--mode disko \
		hosts/common/disks/btrfs-luks-impermanence-disko.nix \
		--arg disk '"{{DRIVE}}"' \
		--arg password '"{{PASSWORD}}"'
	rm /tmp/disko-password


# Run nixos-rebuild on the remote host
[group("building")]
build-host HOST:
	NIX_SSHOPTS="-p10022" nixos-rebuild --target-host {{HOST}} --use-remote-sudo --show-trace --impure --flake .#"{{HOST}}" switch

#
# ========== Nix-Secrets manipulation recipes ==========
#

# Update sops keys in nix-secrets repo
[group("secrets")]
sops-rekey:
  cd ../nix-secrets && for file in $(ls sops/*.yaml); do \
    sops updatekeys -y $file; \
  done

# Update all keys in sops/*.yaml files in nix-secrets to match the creation rules keys
[group("secrets")]
rekey: sops-rekey
  cd ../nix-secrets && \
    (pre-commit run --all-files || true) && \
    git add -u && (git commit -nm "chore: rekey" || true) && git push

# Update an age key anchor or add a new one
[group("secrets")]
sops-update-age-key FIELD KEYNAME KEY:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_update_age_key {{FIELD}} {{KEYNAME}} {{KEY}}

# Update an existing user age key anchor or add a new one
[group("secrets")]
sops-update-user-age-key USER HOST KEY:
  just sops-update-age-key users {{USER}}_{{HOST}} {{KEY}}

# Update an existing host age key anchor or add a new one
[group("secrets")]
sops-update-host-age-key HOST KEY:
  just sops-update-age-key hosts {{HOST}} {{KEY}}

# Automatically create creation rules entries for a <host>.yaml file for host-specific secrets
[group("secrets")]
sops-add-host-creation-rules USER HOST:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_add_host_creation_rules "{{USER}}" "{{HOST}}"

# Automatically create creation rules entries for a shared.yaml file for shared secrets
[group("secrets")]
sops-add-shared-creation-rules USER HOST:
    #!/usr/bin/env bash
    source {{HELPERS_PATH}}
    sops_add_shared_creation_rules "{{USER}}" "{{HOST}}"

# Automatically add the host and user keys to creation rules for shared.yaml and <host>.yaml
[group("secrets")]
sops-add-creation-rules USER HOST:
    just sops-add-host-creation-rules {{USER}} {{HOST}} && \
    just sops-add-shared-creation-rules {{USER}} {{HOST}}

#
# ========== Talon recipes ==========
#

# Add a talon beta linux URL hash to talon-versions.json
[group("talon")]
talon-linux URL:
  just talon linux {{URL}}

# Add a talon beta darwin URL hash to talon-versions.json
[group("talon")]
talon-darwin URL:
  just talon darwin {{URL}}

# Automatically add a new talon version to the talon-versions.json file
[group("talon")]
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

# Copy all the config files to the remote host
[group("admin")]
sync USER HOST PATH:
	rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}} -oport=10022" . {{USER}}@{{HOST}}:{{PATH}}/nix-config

# Create a new user with a password hash for dovecot, to be placed in ooze.yaml secrets
[group("admin")]
dovecot-hash:
    touch /tmp/empty-dovecot.conf
    DOVECONF=/dev/null nix shell nixpkgs#dovecot.out -c doveadm -c /tmp/empty-dovecot.conf pw -s SHA512-CRYPT

# Updates the firefox extension list
[group("admin")]
firefox-addons:
    mozilla-addons-to-nix overlays/firefox/addons.json overlays/firefox/generated.nix
