#!/usr/bin/env bash
# See https://github.com/PerchunPak/ghcherry

set -u

HOST="${1?Missing host argument}"

nixpkgs_rev=$(
    nix flake metadata \
        --reference-lock-file locks/"$HOST".lock \
        --json |
        jq -er '.locks.nodes."nixpkgs-unstable-upstream".locked.rev'
)

mapfile -t prs < <(jq -r '.[] | "NixOS/nixpkgs#\(.number)"' "$(dirname -- "${BASH_SOURCE[0]}")"/tracked-prs.json)

GITHUB_TOKEN=$(cat ~/.config/sops-nix/secrets/tokens/ghcherry) \
    nix run github:NixOS/nixpkgs/nixpkgs-unstable#ghcherry -- \
    --target fidgetingbits/nixpkgs@patched \
    --first-hard-reset-to "NixOS/nixpkgs/$nixpkgs_rev" \
    "${prs[@]}"

nix flake update \
    --reference-lock-file locks/"$HOST".lock \
    --timeout 5 \
    --output-lock-file locks/"$HOST".lock \
    nixpkgs-unstable
