{ ... }:
rec {
  #           --------    ------------
  #           | DP-1 |    | HDMI-A-1 |
  #           --------    ------------
  monitors = {
    "DP-1" = {
      width = 2560;
      height = 2880;
      refreshRate = 120.00;
      #transform = 2;
      scale = 1.0;
      primary = true;
    };
    "HDMI-A-1" = {
      width = 2560;
      height = 2880;
      refreshRate = 120.00;
      #transform = 2;
      x = monitors."DP-1".width;
      scale = 1.0;
    };
  };
}
