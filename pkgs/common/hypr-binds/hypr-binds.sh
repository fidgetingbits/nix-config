# shellcheck disable=SC2148
# Make it easier to quickly find hyprland bindings
# Originally found here: https://github.com/Eduruiz/dotfiles/blob/main/scripts/.config/scripts/hypr-binds/hypr-binds.sh
hyprctl binds -j |
    jq -r '
        map({
            modkey: .modmask | tostring,
            key: .key,
            description: .description,
            dispatch: .dispatcher,
            arg: .arg
        })
        | map(.modkey |= {
            "0": "",
            "1": "SHIFT",
            "4": "CTRL",
            "5": "SHIFT+CTRL",
            "8": "ALT",
            "12": "ALT+CTRL",
            "64": "SUPER",
            "65": "SUPER+SHIFT",
            "68": "SUPER+CTRL",
            "72": "SUPER+ALT",
            "73": "SUPER+ALT+SHIFT"
        } [.] )
        | sort_by(.modkey)
    ' |
    jtbl -n --fancy |
    fzf --layout=reverse-list
