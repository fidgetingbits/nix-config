{
  osConfig,
  lib,
  ...
}:
{
  services.kanshi = {
    enable = true;
    settings = [
      # FIXME: Come up with a way to define profiles via config.monitors?
      {
        profile.name = "default";
        profile.outputs =
          osConfig.monitors
          |> lib.mapAttrsToList (
            name: value: {
              criteria = name;
              status = if value.enabled then "enable" else "disabled";
              mode = "${toString value.width}x${toString value.height}@${toString value.refreshRate}Hz";
              scale = value.scale;
              adaptiveSync = value.vrr != 0;
              position = "${toString value.x},${toString value.y}";
            }
          );
      }
    ];
  };
}
