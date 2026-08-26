{
  lib,
  inputs,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  # When debugging neovim issues it's handy to automate some stuff so you can
  # quickly get going.
  nvim-debug-gdb = pkgs.writeTextFile {
    name = "nvim-debug.gdb";
    text = ''
      set follow-fork-mode parent
      set $home = $_getenv("HOME")

      # Use eval to construct and execute commands dynamically
      eval "directory %s/dev/neovim/neovim/", $home
      eval "set substitute-path /build/source/ %s/dev/neovim/neovim/", $home

      # Shut up [Detaching after fork from child process 902905] spam
      set print inferior-events off

      continue
    '';
  };
  nvim-debug = pkgs.writeShellApplication {
    name = "nvim-debug";
    runtimeInputs = lib.attrValues {
      inherit (pkgs)
        pwndbg
        gawk
        pstree
        procps
        ;
    };
    text = # bash
      ''
        cd ${config.home.homeDirectory}/dev/neovim/neovim || exit 1
        HASH=$(nvim --version | grep nightly | cut -f2 -d+)
        git checkout "$HASH"
        cd - || exit 1
        PID=''${1:-"$(pstree "$(pgrep neovide | tail -1)" | grep "/bin/nvim" | grep -v grep | tail -1 | awk '{print $2}')"}
        if [ -z "$PID" ]; then
          echo "No PID found, or specified, for neovim. Can't debug"
          echo "Usage: ./$0 [PID]"
          echo "If no PID is supplied, tries to debug the /bin/nvim child of the most recent neovide instance"
          exit 1
        fi
        pwndbg -q -x ${nvim-debug-gdb} -p "$PID"
      '';
  };
in
{
  # This is required here now because introdus stopped using mkInstallModule,
  # otherwise introdus will infinite recurse
  imports = [ inputs.fidgetingvim.wrappers.neovim.install ];

  home.packages = lib.optionals osConfig.hostSpec.isDevelopment [ nvim-debug ];

  introdus.neovim = {
    enable = true;
    fontSize = 10;
  };

  # My custom neovim wrapper, built on top of the introdus neovim base, is enabled by the above
  # and exposed in the config as wrappers.neovim.

  wrappers.neovim = {
    # package = pkgs.unstable.neovim-unwrapped;
    # package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
    package =
      let
        nightly = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system};
      in
      if osConfig.hostSpec.isDevelopment then nightly.neovim-debug else nightly.default;

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
