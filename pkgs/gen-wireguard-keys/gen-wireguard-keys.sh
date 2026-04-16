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
    if [ $# -gt 1 ]; then
        secrets="$2" # Override of what secret file to use
    else
        secrets="$secrets_file"
    fi
    # shellcheck disable=SC2116,SC2086
    sops --config "$sops_config" --set "$entry" "$secrets"
}

function gen_keys() {
    host="${1:-}"
    rosenpass gen-keys --secret-key "$host"_pqsk --public-key "$host"_pqpk
    wg genkey | tee "$host"_wgsk | wg pubkey >"$host"_wgpk
    sops_set '["keys"]["wireguard"]["wgsk"] "'"$(cat "$host"_wgsk)"'"'
    pqsk="$PWD"/"$host"_pqsk
    pqpk="$PWD"/"$host"_pqpk
    cd "$NIX_SECRETS_DIR" || exit
    # Encrypt the pqsk as an individual file due to it being binary format
    sops -e "$pqsk" >sops/"$host"_pqsk

    mkdir -p keys || true
    # Copy the binary pubkey file non-encrypted
    cp "$pqpk" keys/
    cd - >/dev/null || exit
}

parse_args "1" "$@"
target_hostname="${POSITIONAL_ARGS[0]}"

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

for name in "${POSITIONAL_ARGS[@]}"; do
    secrets_file="${NIX_SECRETS_DIR}/sops/${target_hostname}.yaml"
    if [ ! -f "${secrets_file}" ]; then
        gum style --bold "ERROR: "
        gum log "${secrets_file} doesn't exist? Did you forget to bootstrap that host?"
        exit 1
    fi
    gen_keys "$name"
done

for name in "${POSITIONAL_ARGS[@]}"; do
    echo "Put the following in nix-secrets network.wireguard.<lan>.peers array:"
    echo "-----"
    echo "{"
    echo "  name = \"$host\";"
    echo "  publicKey= \"$(cat "$host"_wgpk)\";"
    echo "}"

done

if [ "${DEBUG:-}" == 1 ]; then
    echo "Keys were retained in $DIR"
else
    rm -rf "$DIR"
fi
