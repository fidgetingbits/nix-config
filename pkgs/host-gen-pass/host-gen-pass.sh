#!/usr/bin/env bash
# Generate Passwords For New NixOS Host
#
# TODO:
#  - [ ] Color the outputs (ie: red error, etc)
#  - [ ] Recolor the choose dialogs defaults?

function help_and_exit() {
    echo
    echo "NixOS Host Password Generator Helper"
    echo
    echo "USAGE: $(basename "$0") [OPTIONS] <hostname>"
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

function gen_pass {
    phraze -ll -s_b -S -t
}

function gen_u2f_keys {
    function wait_yubikey {
        # Generate a temporary file that will go into
        gum log "Yubikey plugged in?"
        while [ "$(gum choose 'yes' 'no')" != "yes" ]; do
            gum log "Yubikey plugged in?"
        done
    }
    # FIXME: Better way to capture only success result and until loop?
    function read_config {
        cmd=$1
        shift
        # shellcheck disable=SC2048,SC2086
        result=$("$cmd" $*)
        # shellcheck disable=SC2181
        until [ "$?" -eq 0 ]; do
            # shellcheck disable=SC2048,SC2086
            result=$("$cmd" $*)
        done
        echo "$result"
    }

    echo "Generating: $(gum style --bold "U2F keys")"
    echo "$(gum style --bold NOTE:) You will need to plug in your yubikeys one by one"

    wait_yubikey
    entry=$(read_config pamu2fcfg)

    while echo "Do you have another yubikey?" && [ "$(gum choose yes no)" != "no" ]; do
        wait_yubikey
        entry+=$(read_config pamu2fcfg -n)
    done

    sops_set '["keys"]["u2f"] "'"$entry"'"'
}

function gen_borg {
    echo "Generating: $(gum style --bold "borg passphrase")"
    pass=$(gen_pass)
    sops_set '["passwords"]["borg"] "'"$pass"'"'

    echo "Generating: $(gum style --bold ssh keys for borg server access)"

    key_dir=$(mktemp -d)
    cd "$key_dir" || (
        echo "cd $key_dir failed?"
        exit 1
    )
    ssh-keygen -t ed25519 -f id_borg -q -N ''
    # -z Converts newlines to null
    borg_key=$(sed -z 's/\n/\\n/g' id_borg)
    # Change color to important or something
    echo "$(gum style --bold IMPORTANT:) Add the follow pub key to the borg server authorized keys list:"
    \cat id_borg.pub
    cd - >/dev/null || (
        echo cd - failed?
        exit 1
    )

    \rm -rf "$key_dir"

    sops_set '["keys"]["borg"] "'"$borg_key"'"'

}

function gen_postfix {
    echo "Generating: $(gum style --bold "postfix relay passphrase")"

    local pass dove_hash postfix_server sops_file dovecot_existing_hashes
    pass=$(gen_pass)
    sops_set '["passwords"]["postfix-relay"] "'"$pass"'"'

    echo "Generating: $(gum style --bold "corresponding dovecot password entry")"
    dove_hash=$(
        printf "%s\n%s\n" "$pass" "$pass" |
            doveadm -c /dev/null pw -s SHA512-CRYPT
    )

    postfix_server=$(gum input --prompt "Postfix server name: " --placeholder "ooze")
    sops_file="${NIX_SECRETS_DIR}/sops/${postfix_server}.yaml"
    # dovecot hashes are stored all in one sops entry, so append new to old ones
    dovecot_existing_hashes=$(sops --config "$sops_config" -d "$sops_file" | yq .dovecot | tr -d \")

    new="$(printf '%s' "$dovecot_existing_hashes$target_hostname:$dove_hash" | sed -z 's/\n/\\n/')"
    echo sops_set "[\"dovecot\"] '\"$new\"'" "$sops_file"
    sops_set "[\"dovecot\"] \"$new\"" "$sops_file"
}

# Generate an atuin key using pre-existing passphrase
# Requires:
# - Already registered user
# - Access to a remote host that already is authenticated to atuin
function gen_atuin {
    echo "$(gum style --bold IMPORTANT:) This function doesn't support unregistered atuin users, for that do it manually"

    local atuin_user atuin_passphrase
    atuin_user=$(gum input --placeholder "$(id -u -n)" --prompt "Atuin user that is already registered: ")
    atuin_passphrase=$(atuin key)

    if [ -z "$atuin_passphrase" ]; then
        echo "$(gum style --bold ERROR:) gen_atuin(): Host $(hostname) doesn't seem to have access to atuin?"
    fi

    atuin_pass=$(gum input --placeholder "password" --prompt "Atuin user password")
    ssh -q "$target_hostname" atuin login -u "$atuin_user" -p "$atuin_pass" -k "\"$atuin_passphrase\""
    local key_path=~/.local/share/atuin/key
    sops_set '["keys"]["atuin"] "'"$(ssh -q "$target_hostname" cat $key_path)"'"'
    ssh -q "$target_hostname" rm "$key_path"
}

function gen_user_pass {
    echo "$(gum style --bold IMPORTANT:) Don't bother generating if this user already has a password"
    local pass user
    pass=$(mkpasswd -m bcrypt -R 12 -s)
    user=$(gum input --placeholder "$(id -u -n)" --prompt "User to generate password hash: ")
    sops_set '["passwords"]["'"$user"'"] "'"$(cat "$key_path")"'"'
}

function choose {
    name=$1
    callback=$2
    echo "Generate $name?"
    if [ "$(gum choose yes no)" == "yes" ]; then
        "$callback"
    fi
}

gum style --bold 'NixOS Password Generator'

parse_args "1" "$@"
target_hostname="${POSITIONAL_ARGS[0]}"

if [ -z "$NIX_SECRETS_DIR" ]; then
    echo "$(gum style --bold ERROR:) NIX_SECRETS_DIR must point to the nix-secrets folder"
fi

echo "Generating passwords for $(gum style --bold "$target_hostname")"

key_path="$XDG_RUNTIME_DIR/secrets.d/age-keys.txt"
if [ ! -f "$key_path" ]; then
    echo "$(gum style --bold ERROR:) Required age key $(gum style --bold "$key_path") doesn't exist. Run this script from a dev box with access to the nix-secrets sops files"
fi
sops_config="${NIX_SECRETS_DIR}/.sops.yaml"
secrets_file="${NIX_SECRETS_DIR}/sops/${target_hostname}.yaml"
if [ ! -f "${secrets_file}" ]; then
    gum style --bold "ERROR: "
    gum log "${secrets_file} doesn't exist? Did you forget to bootstrap that host?"
    exit 1
fi

choose "U2F Keys (Must physically insert yubikeys to target host)" gen_u2f_keys

choose "Borg Password" gen_borg
choose "Postfix Relay Password" gen_postfix
# FIXME: If they select no to postfix, we should tell them to set the manual msmtp?
choose "Atuin Key" gen_atuin
choose "User password" gen_user_pass

gum log "All done!"
