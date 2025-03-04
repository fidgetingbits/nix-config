{ ... }:

{

  # Direnv, load and unload environment variables depending on the current directory.
  # https://direnv.net
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true; # Better than native direnv nix functionality, see https://github.com/nix-community/nix-direnv

    # Turn off verbosity, https://github.com/direnv/direnv/issues/68
    config.global = {
      hide_env_diff = true;
    };
  };
}
