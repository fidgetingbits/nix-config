{ ... }:
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ]; # Apply to all keyboards
      settings = {
        main = {
          capslock = "overload(control, esc)";
          rightalt = "overload(meta, compose)";
          leftcontrol = "layer(layer1)";
          rightcontrol = "layer(layer1)";
          menu = "super"; # NOTE: this key only on onyx
          escape = "noop";
        };
        layer1 = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";
        };
        shift = {
          leftshift = "capslock";
          rightshift = "capslock";
        };
      };
    };
  };

  # Sometimes shits itself, so make it restart
  systemd.services.key.serviceConfig.Restart = "always";
}
