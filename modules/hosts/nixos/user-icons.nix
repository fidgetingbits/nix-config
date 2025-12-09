{
  config,
  lib,
  ...
}:
{

  # Links per-user ~/.face.icon files to /var/lib/AccountsService/icons
  #
  # This seems way nicer:
  # https://github.com/NixOS/nixpkgs/issues/163080#issuecomment-1722465663
  # But the caveat is you'd need to set the per-user icon from nixos not hm, so
  # not bothering yet.
  #
  # May get changed by https://github.com/NixOS/nixpkgs/issues/73976
  # or https://github.com/NixOS/nixpkgs/issues/163080
  #
  # WARNING: I clobber /var/lib/AccountsService/users/${user}, but gdm
  # also uses this, so may actually cause issues. Tested with sddm only
  systemd.tmpfiles.rules =
    let
      users = config.home-manager.users;
    in
    lib.attrNames users
    |> builtins.filter (user: users.${user}.home.file ? ".face.icon")
    |> builtins.map (user: [
      "d /var/lib/AccountsService/users 0755 root root -"
      "d /var/lib/AccountsService/icons 0755 root root -"
      "f+ /var/lib/AccountsService/users/${user}  0600 root root -  [User]\\nIcon=/var/lib/AccountsService/icons/${user}\\n"
      "L+ /var/lib/AccountsService/icons/${user}  -    -    -    -  ${
        users.${user}.home.file.".face.icon".source
      }"
    ])
    |> lib.flatten;
}
