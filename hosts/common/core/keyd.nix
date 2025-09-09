{ ... }:
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ]; # Apply to all keyboards
      settings = {
        main = {
          # NOTE: This conflicts with zsh sudo plugin in that sometimes too quick
          # ctrl+<key> or similar presses will add a sudo to a command
          capslock = "overload(control, esc)";
          enter = "overload(control, enter)";
          # Careful with this due to typing too fast
          # space = "overload(alt, space)";
          rightalt = "overload(meta, compose)";
          leftcontrol = "layer(layer1)";
          rightcontrol = "layer(layer1)";
          # FIXME: this key only on onyx
          menu = "super";
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
}
