{
  lib,
  stdenv,
  pkgs,
  ...
}:
let
  pname = "zsh-color-ssh-nvim-term";
  install_path = "share/zsh/${pname}";

  # Inlined because we need to use the neovim-python-scripts package
  scriptFile = pkgs.writeShellScriptBin "${pname}.plugin.zsh" ''
        function set_nvim_term_ssh_color() {
        # Check if incoming command is ssh
        if [[ "$1" =~ "ssh" ]] && [ -n "$NVIM" ]; then
            ${pkgs.neovim-python-scripts}/bin/neovim-change-bg-color black
        fi
        export NVIM_TERM_SSH_COLOR_SET=1
    }

    function unset_nvim_term_ssh_color() {
        if [ -n "''${NVIM_TERM_SSH_COLOR_SET}" ]; then
          ${pkgs.neovim-python-scripts}/bin/neovim-change-bg-color None
          unset NVIM_TERM_SSH_COLOR_SET
        fi
    }

    autoload -Uz add-zsh-hook
    add-zsh-hook preexec set_nvim_term_ssh_color
    add-zsh-hook precmd unset_nvim_term_ssh_color
  '';
in
stdenv.mkDerivation {
  name = pname;
  strictDeps = true;
  dontBuild = true;
  dontUnpack = true;
  runtimeInputs = [ pkgs.neovim-python-scripts ];
  installPhase = ''
    install -m755 -D ${scriptFile}/bin/${pname}.plugin.zsh $out/${install_path}/${pname}.plugin.zsh
  '';
  meta = {
    license = lib.licenses.mit;
    longDescription = ''
      This Zsh plugin creates a hook to automatically change the neovim background when executing ssh.

      To install the ${pname} plugin you can add the following to your `programs.zsh.plugins` list:

      ```nix
        programs.zsh.plugins = [
      {
      name = "${pname}";
      src = "''${pkgs.${pname}}/${install_path}";
      }
      ];
      ```
    '';

    maintainers = [ lib.maintainers.fidgetingbits ];
  };
}
