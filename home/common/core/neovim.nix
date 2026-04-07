{
  lib,
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
    settings = {
      # Set impure paths to allow hot reloading of `plugin/`, `snippets/`, etc
      unwrappedConfig = "/home/aa/dev/nix/neovim";
      baseConfig = lib.mkForce "/home/aa/dev/nix/introdus/aa/wrappers/neovim";
    };
  };
  xdg.desktopEntries.nvim-neovide = {
    name = "Neovide (Nvim Wrapper)";
    genericName = "Text Editor";
    exec = "nvim-neovide %F";
    icon = "nvim";
    terminal = false;
    categories = [
      "Utility"
      "TextEditor"
    ];
    settings = {
      StartupWMClass = "neovide";
    };
  };
}
