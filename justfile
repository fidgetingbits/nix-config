export HELPERS_PATH := justfile_directory() + "../introdus/pkgs/introdus-helpers/helpers.sh"

[private]
default:
    @just --list

# Copy the target hosts lock file, creating it if it doesn't already exist
[private]
copy-lock-in HOST=`hostname`:
    @mkdir -p locks
    @cp locks/{{ HOST }}.lock flake.lock || cp locks/$(hostname).lock locks/{{ HOST }}.lock && git add locks/{{ HOST }}.lock && cp locks/{{ HOST }}.lock flake.lock
    @git add --intent-to-add -f flake.lock
    @git update-index --assume-unchanged flake.lock

[private]
copy-lock-out HOST=`hostname`:
    @mkdir -p locks
    @cp flake.lock locks/{{ HOST }}.lock
    @git rm --cached -f flake.lock > /dev/null || true
    @rm flake.lock || true

# Update commonly changing flakes and prep for a build
[private]
rebuild-pre HOST=`hostname`:
    just update-nix-secrets {{ HOST }} && \
    just update {{ HOST }} nix-assets && \
    just update {{ HOST }} nixcats-flake && \
    just update {{ HOST }} nix-index-database && \
    just update {{ HOST }} introdus
    @git add --intent-to-add .

# Run post-build checks, like if sops is running properly afterwards
[private]
rebuild-post: check-sops

# Run a flake check on the config and installer
[group("checks")]
check HOST=`hostname` ARGS="":
    @just copy-lock-in {{ HOST }}
    NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check \
        --impure \
        --keep-going \
        --show-trace \
        {{ ARGS }}
    cd nixos-installer && \
        NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check \
        --impure \
        --keep-going \
        --show-trace \
        {{ ARGS }}
    @just copy-lock-out {{ HOST }}

# Rebuild specified host
[group("building")]
rebuild HOST=`hostname`: && rebuild-post
    @just rebuild-host {{ HOST }}
    # just rebuild-extensions-lite

# Rebuild specified host and then run a flake check
[group("building")]
rebuild-full HOST=`hostname`: && rebuild-post
    @just rebuild-host {{ HOST }}
    just check {{ HOST }}
    # just rebuild-extensions

# Update all flake inputs for the specified host or the current host if none specified
[group("update")]
update HOST=`hostname` *INPUT:
    @just copy-lock-in {{ HOST }}
    nix flake update {{ INPUT }} --timeout 5
    @just copy-lock-out {{ HOST }}

# Update and then rebuild
[group("building")]
upgrade: update rebuild

# Generate a new age key
[group("secrets")]
age-key:
    nix-shell -p age --run "age-keygen"

# Check if sops-nix activated successfully
[group("checks")]
check-sops:
    check-sops

# Update nix-secrets flake
[group("update")]
update-nix-secrets HOST=`hostname`:
    @(cd ../nix-secrets 2>/dev/null && git fetch && git rebase > /dev/null || echo "Push your nix-secrets changes") || true
    @just update {{ HOST }} nix-secrets

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
iso HOST=`hostname`:
    # If we dont remove this folder, libvirtd VM doesnt run with the new iso
    rm -rf result
    nix build --impure .#nixosConfigurations.iso.config.system.build.isoImage --reference-lock-file locks/{{ HOST }}.lock && ln -sf result/iso/*.iso latest_{{ HOST }}.iso

# Install the latest iso to a flash drive
[group("building")]
iso-install DRIVE HOST=`hostname`:
    just iso {{ HOST }}
    sudo dd if=$(eza --sort changed result/iso/*.iso | tail -n1) of={{ DRIVE }} bs=4M status=progress oflag=sync

# FIXME: This is deprecated now I think

# Configure a drive password using disko
[group("misc")]
disko DRIVE PASSWORD:
    echo "{{ PASSWORD }}" > /tmp/disko-password
    sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
    	--mode disko \
    	hosts/common/disks/btrfs-luks-impermanence-disko.nix \
    	--arg disk '"{{ DRIVE }}"' \
    	--arg password '"{{ PASSWORD }}"'
    rm /tmp/disko-password

# Run nixos-rebuild on the remote host
[group("building")]
rebuild-host HOST=`hostname`:
    #!/usr/bin/env bash
    just rebuild-pre {{ HOST }}
    BUILD_FOLDER=$(mktemp -d)
    echo "Prepping build folder: $BUILD_FOLDER"
    cp -R . "$BUILD_FOLDER"
    trap 'rm -rf $BUILD_FOLDER' EXIT
    cd $BUILD_FOLDER
    just copy-lock-in {{ HOST }}
    rebuild-host {{ HOST }}
    just copy-lock-out {{ HOST }}
    cd -

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
    source {{ HELPERS_PATH }}
    sops_update_age_key {{ FIELD }} {{ KEYNAME }} {{ KEY }}

# Update an existing user age key anchor or add a new one
[group("secrets")]
sops-update-user-age-key USER HOST KEY:
    just sops-update-age-key users {{ USER }}_{{ HOST }} {{ KEY }}

# Update an existing host age key anchor or add a new one
[group("secrets")]
sops-update-host-age-key HOST KEY:
    just sops-update-age-key hosts {{ HOST }} {{ KEY }}

# Automatically create creation rules entries for a <host>.yaml file for host-specific secrets
[group("secrets")]
sops-add-host-creation-rules USER HOST:
    #!/usr/bin/env bash
    source {{ HELPERS_PATH }}
    sops_add_host_creation_rules "{{ USER }}" "{{ HOST }}"

# Automatically create creation rules entries for a shared.yaml file for shared secrets
[group("secrets")]
sops-add-shared-creation-rules USER HOST:
    #!/usr/bin/env bash
    source {{ HELPERS_PATH }}
    sops_add_shared_creation_rules "{{ USER }}" "{{ HOST }}"

# Automatically add the host and user keys to creation rules for shared.yaml and <host>.yaml
[group("secrets")]
sops-add-creation-rules USER HOST:
    just sops-add-host-creation-rules {{ USER }} {{ HOST }} && \
    just sops-add-shared-creation-rules {{ USER }} {{ HOST }}

#
# ========== Talon recipes ==========
#

# Add a talon beta linux URL hash to talon-versions.json
[group("talon")]
talon-linux URL:
    just talon linux {{ URL }}

# Add a talon beta darwin URL hash to talon-versions.json
[group("talon")]
talon-darwin URL:
    just talon darwin {{ URL }}

# Automatically add a new talon version to the talon-versions.json file
[group("talon")]
talon OS URL:
    cd ../nix-secrets && \
    if grep {{ URL }} talon-versions.json; then \
      echo "URL already exists in talon-versions.json"; \
      exit 1; \
    fi && \
    sha256=$(nix-prefetch-url --unpack {{ URL }}) && \
    jq --arg url "{{ URL }}" \
       --arg sha "$sha256" \
       '.["talon-{{ OS }}-beta"] = {"url": $url, "sha256": ("sha256:" + $sha)}' \
       talon-versions.json > temp.json && \
    mv temp.json talon-versions.json && \
    git add talon-versions.json && \
    git commit -nm "chore: update talon-{{ OS }}-beta" && \
    git push

#
# ========= Admin Recipes ==========
#

# Pin the current nixos generation of a host to the systemd-boot loader menu
[group("admin")]
pin HOST=`hostname`:
    pin-systemd-boot-entry {{ HOST }}

# Copy all the config files to the remote host
[group("admin")]
sync USER HOST PATH:
    rsync -av --filter=':- .gitignore' -e "ssh -l {{ USER }} -oport=10022" . {{ USER }}@{{ HOST }}:{{ PATH }}/nix-config

# FIXME: Deprecated in favor of gen-pass

# Create a new user with a password hash for dovecot, to be placed in ooze.yaml secrets
[group("admin")]
dovecot-hash:
    touch /tmp/empty-dovecot.conf
    DOVECONF=/dev/null nix shell nixpkgs#dovecot.out -c doveadm -c /tmp/empty-dovecot.conf pw -s SHA512-CRYPT

# Updates the firefox extension list
[group("admin")]
firefox-addons:
    mozilla-addons-to-nix overlays/firefox/addons.json overlays/firefox/generated.nix

# Turn off mdadm raid5 resync that inhibits restart from nixos-anywhere during boot
[group("admin")]
turn-off-raid-resync:
    ssh aa@myth "sudo /bin/sh -c 'echo frozen > /sys/block/md127/md/sync_action; \
        echo none > /sys/block/md127/md/resync_start; \
        echo idle > /sys/block/md127/md/sync_action'"

# Generate remote facter.json and add it to the repo. Mostly for migrating hosts. Use nixos-bootstrap otherwise
[group("admin")]
facter HOST:
    #!/usr/bin/env bash
    if ssh {{ HOST }} "sudo /bin/sh -c 'nix run --option experimental-features \"nix-command flakes\" nixpkgs#nixos-facter -- -o facter.json' && sudo chmod 644 facter.json" && \
    scp {{ HOST }}:/home/$USER/facter.json hosts/nixos/{{ HOST }}/ && \
    chown $USER:$(id -g) hosts/nixos/{{ HOST }}/facter.json; then
        if ! grep facter .gitattributes | grep -q crypt; then
            echo "WARNING: You are potenttially exposing your facter.json file publicly. Add a git-crypt entry to .gitattributes"
            exit 0
        else
            echo "Added and generated hosts/nixos/{{ HOST }}/facter.json"
            git add hosts/nixos/{{ HOST }}/facter.json
        fi
    fi

# Refresh dev environment with updated inputs
[group("dev")]
dev:
    @just rebuild-pre
    direnv reload

[group("dev")]
fmt:
    nix fmt --reference-lock-file locks/$(hostname).lock
