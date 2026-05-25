# Automatically add some conveniences when the host has microvm
# microvms setup

{
  lib,
  config,
  osConfig,
  namespace,
  ...
}:
let
  cfg = osConfig.${namespace}.ai-agents;
  home = config.home.homeDirectory;
  microvmPath = "/var/lib/microvms";
in

lib.mkIf (lib.length (lib.attrNames cfg.vms) != 0) {

  # Automatic ssh entries
  programs.ssh.matchBlocks =
    cfg.vms
    |> lib.attrNames
    |> map (
      name:
      let
        microvm = cfg.vms.${name};
      in
      {
        "${name}" = {
          match = "host ${name}";
          hostname = microvm.ip;
          port = microvm.sshPort;
          user = microvm.user;
          identityFile = "${home}/.ssh/id_ed25519";
        };
      }
    )
    |> lib.mergeAttrsList;

  home.sessionVariables = {
    AGENTS_STATE_DIR = "${home}/.local/state/ai-agents";
  };

  programs.zsh = {
    shellAliases = {
      # microvm-specific helpers
      # FIXME: cmds to run should come from vm definition in nixos
      # and names should auto-derive
      claude = "ssh claude claude";
      pi = "ssh pi pi";
      codex = "ssh codex codex";

      # Microvm management
      cas = "${home}/.local/state/ai-microvms"; # cd agent state
      mv-start = "function _mv-start() { systemctl start microvm@$1 }; _mv-start";
      mv-stop = "function _mv-stop() { systemctl stop microvm@$1 }; _mv-stop";
      mv-restart = "function _mv-restart() { systemctl stop microvm@$1 }; _mv-restart";
      mv-status = "_mv-status";
      mv-status-all = "_mv-status-all";
      mv-log-all = "_mv-log-all";
      mv-deps = "function _mv-deps() { systemctl list-dependencies \"microvm@$1.service\" }; _mv-deps";
      # FIXME: add helpers for only ones booted/running? like logs for failed only
      # add stuff to dump the network?
      # add zsh completions?
      # FIXME
      mv-list = "ls ${microvmPath}";
      mv-list-running = "systemctl list-units \"microvm@*.service\" --state=running";
      mv-list-stopped = "systemctl list-units \"microvm@*.service\" --state=inactive";
      mvl = "mv-list";
      mvlr = "mv-list-running";
      mvls = "mv-list-stopped";
    };
    # Helper functions for aliases that are annoying to inline
    initContent =
      lib.mkAfter
        # bash
        ''
          function get_microvms() {
            if [ $# -gt 0 ]; then
              echo "$1"
            else
              ls -1 ${microvmPath}
            fi
          }

          # Show systemctl status for the main service of one or more microvms
          function _mv-status() {
            for vm in $(get_microvms "$@"); do
              systemctl status "microvm@$vm.service"
            done
          };

          # Return status of all services related to one or more vm's
          function _mv-status-all() {
            for vm in $(get_microvms "$@"); do
              systemctl status "*@$vm.service"
            done
          };

          function _mv-log-all() {
            local args=()
            for vm in $(get_microvms "$@"); do
              args+=("-u" "$vm")
            done
            journalctl ''${args[@]} -e;
          };
        '';
  };

}
