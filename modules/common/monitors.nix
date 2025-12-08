{ config, lib, ... }:
{
  options.monitors = lib.mkOption {
    description = "List of monitors for use by hyprland, kanshi, etc";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            example = "DP-1";
            default = config._module.args.name;
          };
          primary = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          noBar = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          width = lib.mkOption {
            type = lib.types.int;
            example = 1920;
          };
          height = lib.mkOption {
            type = lib.types.int;
            example = 1080;
          };
          refreshRate = lib.mkOption {
            type = lib.types.float;
            default = 60;
          };
          x = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };
          y = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };
          scale = lib.mkOption {
            type = lib.types.float;
            default = 1.0;
          };
          transform = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          workspace = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Defines a workspace that should persist on this monitor.";
            default = null;
          };
          vrr = lib.mkOption {
            type = lib.types.int;
            description = "Variable Refresh Rate aka Adaptive Sync aka AMD FreeSync.\nValues are oriented towards hyprland's vrr values which are:\n0 = off, 1 = on, 2 = fullscreen only\nhttps://wiki.hyprland.org/Configuring/Variables/#misc";
            default = 0;
          };

        };
      }
    );
    default = { };
  };
  # FIXME: This assert is only relevant if using something that uses the
  # monitors module for now, like hyprland, so should move
  # config = {
  #   assertions = [
  #     {
  #       assertion =
  #         ((lib.length config.monitors) != 0)
  #         -> ((lib.length (lib.filter (m: m.primary) config.monitors)) == 1);
  #       message = "Exactly one monitor must be set to primary.";
  #     }
  #   ];
  # };
}
