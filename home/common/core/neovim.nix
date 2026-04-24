{
  lib,
  inputs,
  osConfig,
  pkgs,
  ...
}:
{
  introdus.neovim = {
    enable = true;
    wrapper = "fidgetingvim";
  };

  # My custom neovim wrapper, built on top of the introdus neovim base, is enabled by the above
  # and exposed in the config as wrappers.neovim.

  wrappers.neovim = {
    package = pkgs.unstable.neovim-unwrapped;
    settings =
      if osConfig.hostSpec.isIntrodusDev then
        {
          # Set impure paths to allow hot reloading of `plugin/`, `snippets/`, etc
          unwrappedConfig = "/home/aa/dev/nix/neovim";
          baseConfig = lib.mkForce "/home/aa/dev/nix/introdus/aa/wrappers/neovim";
        }
      else
        {
          hotReload = false;
          # Non-development boxes just use whatever is already in git
          baseConfig = lib.mkForce "${inputs.introdus-git}/wrappers/neovim";
        };
  };
}
