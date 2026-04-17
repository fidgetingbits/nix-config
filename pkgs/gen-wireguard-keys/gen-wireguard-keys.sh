#!/usr/bin/env bash
# Generate Wireguard and Rosenpass keys

function help_and_exit() {
    echo
    echo "Wireguard/rosenpass key generator"
    echo
    echo "USAGE: $(basename "$0") [OPTIONS] <host1> <host2> <host3>"
    echo
    echo "OPTIONS:"
    echo "  --debug         Enable debug output"
    echo "  -h, --help      Show this help message and exit"
    echo
    exit 1
}

parse_args() {
    local min_args=$1
    shift

    if [ $# -lt "$min_args" ]; then
        help_and_exit
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --debug)
            DEBUG=1
            if [ $# -lt $((min_args + 1)) ]; then
                help_and_exit
            fi
            set -x
            ;;
        -h | --help)
            help_and_exit
            ;;
        *)
            if [ -z "${POSITIONAL_ARGS-}" ]; then
                POSITIONAL_ARGS=()
            fi
            POSITIONAL_ARGS+=("$1")
            ;;
        esac
        shift
    done
}

function sops_set {
    entry=$1
    secrets="$2"
    if [ ! -f "${secrets}" ]; then
        gum style --bold "ERROR: "
        gum log "${secrets} doesn't exist?"
        exit 1
    fi
    # shellcheck disable=SC2116,SC2086
    sops --config "$sops_config" --set "$entry" "$secrets"
}

function gen_keys() {
    host="${1:-}"
    gum log "Generating keys for $host"
    rosenpass gen-keys --secret-key "$host"_pqsk --public-key "$host"_pqpk
    wg genkey | tee "$host"_wgsk | wg pubkey >"$host"_wgpk
    sops_set '["keys"]["wireguard"]["wgsk"] "'"$(cat "$host"_wgsk)"'"' "${NIX_SECRETS_DIR}/sops/${host}.yaml"
    pqsk="$PWD"/"$host"_pqsk
    pqpk="$PWD"/"$host"_pqpk
    cd "$NIX_SECRETS_DIR" || exit
    # Encrypt the pqsk as an individual file due to it being binary format
    sops -e "$pqsk" >sops/"$host"_pqsk
    chown "$SUDO_UID:$SUDO_GID" sops/"$host"_pqsk

    mkdir -p keys || true
    # Copy the binary pubkey file non-encrypted
    cp "$pqpk" keys/
    cd - >/dev/null || exit
}

parse_args "1" "$@"

if [ -z "$NIX_SECRETS_DIR" ]; then
    echo "$(gum style --bold ERROR:) NIX_SECRETS_DIR must point to the nix-secrets folder"
fi

gum style --bold 'Wireguard/Rosenpass Key Generator'

key_path="$XDG_RUNTIME_DIR/secrets.d/age-keys.txt"
if [ ! -f "$key_path" ]; then
    echo "$(gum style --bold ERROR:) Required age key $(gum style --bold "$key_path") doesn't exist. Run this script from a dev box with access to the nix-secrets sops files"
fi
sops_config="${NIX_SECRETS_DIR}/.sops.yaml"

if [ "$UID" != 0 ]; then
    echo "ERROR: Script should be run as root to ensure key safety"
    exit 1
fi

DIR=$(mktemp -d -p /root/)
cd "$DIR" || exit

if [ "${DEBUG:-}" == 1 ]; then
    echo "Keys will be retained in $DIR"
else
    trap 'rm -rf "$DIR"' EXIT
fi

for host in "${POSITIONAL_ARGS[@]}"; do
    gen_keys "$host"
done

echo "Put the following in mkHost entry for eeach host in nix-secrets"
echo "-----"
for host in "${POSITIONAL_ARGS[@]}"; do
    echo "${host}: wgpk = \"$(cat "$host"_wgpk)\";"
done
