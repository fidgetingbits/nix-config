SOPS_FILE := "../nix-secrets/.sops.yaml"

# Define path to helpers
export HELPERS_PATH := justfile_directory() + "/scripts/helpers.sh"


# List available commands
default:
  @just --list

# Update commonly changing flakes and prep for a rebuild
rebuild-pre: update-nix-secrets
	nix flake update nixvim-flake --timeout 5
	@git add --intent-to-add .

# Run post-rebuild checks, like if sops is running properly afterwards
rebuild-post: check-sops && save-lock-changes

# Check if the local flake.lock changed, and if so commit it to locks/
save-lock-changes:
    @mkdir -p locks || true; \
    new_hash=$(md5sum flake.lock | cut -d' ' -f1); \
    if [ ! -f "locks/$(hostname).lock" ] || [ "$new_hash" != "$(md5sum locks/$(hostname).lock | cut -d' ' -f1)" ]; then \
        cp flake.lock "locks/$(hostname).lock" && \
        git add "locks/$(hostname).lock" && \
        git commit -m "chore: update $(hostname)'s flake.lock" && \
        git push; \
    fi

# Run a flake check on the config and installer
check ARGS="":
	NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check --impure --keep-going --show-trace {{ARGS}}
	cd nixos-installer && NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check --impure --keep-going --show-trace {{ARGS}}

# Rebuild the system
rebuild: rebuild-pre && rebuild-post
	# NOTE: Add --option eval-cache false if you end up caching a failure you cant get around
	scripts/rebuild.sh
	just rebuild-extensions-lite

# Rebuild the system and run a flake check
rebuild-full: rebuild-pre && rebuild-post
	scripts/rebuild.sh
	just check
	just rebuild-extensions

# Rebuild the system with tshow trace
rebuild-trace: rebuild-pre && rebuild-post
	scripts/rebuild.sh trace
	just rebuild-extensions-lite

# Update all flake inputs
update:
	nix flake update

# Update and then rebuild
rebuild-update: update rebuild

# Generate a new age key
age-key:
	nix-shell -p age --run "age-keygen"

# Check if sops-nix activated successfully
check-sops:
	scripts/check-sops.sh

# Update nix-secrets flake
update-nix-secrets:
	@(cd ../nix-secrets && git fetch && git rebase > /dev/null) || true
	nix flake update nix-secrets --timeout 5

# Rebuild vscode extensions that update regularly
rebuild-extensions:
	scripts/build-vscode-extensions.sh || true

# Install vscode extensions, but don't rebuild
rebuild-extensions-lite:
	scripts/build-vscode-extensions.sh lite || true

# Build an iso image for installing new systems and create a symlink for qemu usage
iso:
	# If we dont remove this folder, libvirtd VM doesnt run with the new iso
	rm -rf result
	nix build --impure .#nixosConfigurations.iso.config.system.build.isoImage && ln -sf result/iso/*.iso latest.iso

# Install the latest iso to a flash drive
iso-install DRIVE: iso
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
