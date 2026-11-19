# Shared recipes

[private]
default:
    @just --list

[private]
copy-lock-in HOST=`hostname`:
    @mkdir -p locks
    @cp locks/{{ HOST }}.lock flake.lock || (cp locks/$(hostname).lock locks/{{ HOST }}.lock && git add locks/{{ HOST }}.lock && cp locks/{{ HOST }}.lock flake.lock)
    @git add --intent-to-add -f flake.lock
    @git update-index --assume-unchanged flake.lock

[private]
copy-lock-out HOST=`hostname`:
    @mkdir -p locks
    @cp flake.lock locks/{{ HOST }}.lock 2>/dev/null && \
    (git rm --cached -f flake.lock > /dev/null || true) && \
    rm -f flake.lock || true

# Run post-build checks, like if sops is running properly afterwards
[private]
rebuild-post: check-sops

# Check if sops-nix activated successfully
[group("checks")]
check-sops:
    check-sops

[group("checks")]
check HOST=`hostname` ARGS="":
    #!/usr/bin/env bash
    BUILD_FOLDER=$(mktemp -d)
    echo "Prepping build folder: $BUILD_FOLDER"
    cp -R . "$BUILD_FOLDER"
    trap 'rm -rf "$BUILD_FOLDER"' EXIT
    cd "$BUILD_FOLDER"

    NIXPKGS_ALLOW_UNFREE=1 REPO_PATH=$(pwd) nix flake check \
        --impure \
        --keep-going \
        --show-trace \
        --reference-lock-file locks/{{ HOST }}.lock \
        --output-lock-file locks/{{ HOST }}.lock \
        {{ ARGS }}

# Rebuild specified host
[group("building")]
rebuild HOST=`hostname` NO_SWITCH="0": && rebuild-post
    @just rebuild-host {{ HOST }} {{ NO_SWITCH }}

# Rebuild specified host, but don't auto-switch
[group("building")]
boot HOST=`hostname`:
    @just rebuild-host {{ HOST }} 1

# Rebuild specified host and then run a flake check
[group("building")]
rebuild-full HOST=`hostname`: && rebuild-post
    @just rebuild-host {{ HOST }}
    just check {{ HOST }}

# Run nixos-rebuild on the remote host
[group("building")]
rebuild-host HOST=`hostname` NO_SWITCH="0":
    #!/usr/bin/env bash
    just rebuild-pre {{ HOST }}
    BUILD_FOLDER=$(mktemp -d)
    echo "Prepping build folder: $BUILD_FOLDER"
    cp -R . "$BUILD_FOLDER"
    trap 'rm -rf "$BUILD_FOLDER"' EXIT
    cd "$BUILD_FOLDER"
    just copy-lock-in {{ HOST }}
    if [ "{{ NO_SWITCH }}" != "1" ]; then
        rebuild-host {{ HOST }}
    else
        rebuild-host --no-switch {{ HOST }}
    fi
    just copy-lock-out {{ HOST }}
    cd - >/dev/null
