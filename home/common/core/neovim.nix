{
  lib,
  inputs,
  config,
  osConfig,
  pkgs,
  ...
}:
{
  introdus.neovim = {
    enable = true;
    wrapper = "fidgetingvim";
    fontSize = 10;
  };

  # My custom neovim wrapper, built on top of the introdus neovim base, is enabled by the above
  # and exposed in the config as wrappers.neovim.

  wrappers.neovim = {
    package = pkgs.unstable.neovim-unwrapped;

    # We need some sops-secret-based environment variables on development boxes, and
    # won't inherit them from zsh since we are typically running neovide
    env = lib.optionalAttrs osConfig.hostSpec.isDevelopment (
      let
        # FIXME: This is now duplicated 3 places.. it should be templated somewhere?
        keys = {
          ANTHROPIC_API_KEY = "anthropic";
          OPENAI_API_KEY = "openai";
          GEMINI_API_KEY = "google";
          OPENROUTER_API_KEY = "openrouter";
          DEEPSEEK_API_KEY = "deepseek";
          NVIDIA_API_KEY = "nvidia";
        };
      in
      (
        keys
        |> lib.attrNames
        |> map (k: {
          ${k} = {
            data = ''"$(cat ${config.sops.secrets."tokens/${keys.${k}}".path})"'';
            esc-fn = v: v;
          };
        })
        |> lib.mergeAttrsList
      )
      // {
        # FIXME: Some of this could be passed in nixInfo I think?
        LLAMA_SWAP_API_KEY = {
          data = "foo";
        };
        LLAMA_SWAP_PORT = {
          data = "${toString osConfig.hostSpec.networking.ports.tcp.llama-swap}";
        };
        OEDO = {
          data = "oedo.${osConfig.hostSpec.domain}";
        };
        OSSA = {
          data = "ossa.${osConfig.hostSpec.domain}";
        };
      }
    );

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
