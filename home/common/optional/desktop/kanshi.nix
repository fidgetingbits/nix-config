{
  osConfig,
  lib,
  namespace,
  ...
}:
{
  services.kanshi = {
    enable = true;
    settings = [
      # FIXME: Come up with a way to define profiles via config.${namespace}.monitors?
      {
        profile.name = "default";
        profile.outputs =
          osConfig.${namespace}.monitors
          |> lib.mapAttrsToList (
            name: value: {
              criteria = name;
              status = if value.enabled then "enable" else "disabled";
              mode = "${toString value.width}x${toString value.height}@${toString value.refreshRate}Hz";
              inherit (value) scale;
              adaptiveSync = value.vrr != 0;
              position = "${toString value.x},${toString value.y}";
            }
          );
      }
    ];
  };
}
