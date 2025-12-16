# NOTE: Underlying persistence modules only get added if the system uses impermanence
# FIXME: contemplate the merits of adding here, vs other inline locations. Seems like
# for some things we'll want both
# Good list of stuff to double check: https://github.com/matthewpi/nixos-config/blob/master/modules/persistence/default.nix
{ lib, ... }:
{
  imports = lib.custom.scanPaths ./.;
}
