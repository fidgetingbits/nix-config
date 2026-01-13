#!/usr/bin/env bash

# Host that contains the dovecot secrets for postfix
DEFAULT_POSTFIX_SERVER="ooze"

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

# NOTE: This doesn't use ssh so assumes the host adding the yubikey
# is locally running the script. However the devices I use yubikey on
# are generally development boxes, so it's reasonable to assume that box
# will have the nix-secrets folder cloned
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
    echo "Generating: $(gum style --bold borg passphrase)"
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
    echo "Generating: $(gum style --bold postfix relay passphrase)"
    pass=$(gen_pass)
    sops_set '["passwords"]["postfix-relay"] "'"$pass"'"'

    echo "Generating: $(gum style --bold corresponding dovecot password entry)"
    dove_hash=$(
        printf "%s\n%s\n" "$pass" "$pass" |
            doveadm -c /dev/null pw -s SHA512-CRYPT
    )

    dovecot=$(sops --config "$sops_config" -d "${NIX_SECRETS_DIR}/sops/${POST_FIX_SERVER:-$DEFAULT_POSTFIX_SERVER}.yaml" | yq .dovecot)
    new=$(echo "$dovecot" "$dove_hash" | sed -z 's/\n/\\n/')
    sops_set "[\"dovecot\"] '$new'" "${NIX_SECRETS_DIR}/sops/ooze.yaml"
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
if [ "$#" -lt 1 ]; then
    target_hostname="$(hostname)"
else
    target_hostname="$1"
fi

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
# FIXME: If they select no, we should tell them to set the manual msmtp?
# password? Need to revisit how that generation works
# Add atuin ?
