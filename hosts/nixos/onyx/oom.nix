{ lib, ... }:
{

  # OOM configuration (https://discourse.nixos.org/t/nix-build-ate-my-ram/35752)
  # FIXME: Make this generic eventually
  systemd = {
    # Create a separate slice for nix-daemon that is
    # memory-managed by the userspace systemd-oomd killer
    slices."nix-daemon".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
    };
    services."nix-daemon".serviceConfig.Slice = "nix-daemon.slice";

    # If a kernel-level OOM event does occur anyway,
    # strongly prefer killing nix-daemon child processes
    services."nix-daemon".serviceConfig.OOMScoreAdjust = 1000;
  };
  # Use 50% of cores to try to reduce memory pressure
  nix.settings.cores = lib.mkDefault 2; # FIXME: Can we use nixos-hardware to know the core count?
  nix.settings.max-jobs = lib.mkDefault 2;
  nix.daemonCPUSchedPolicy = lib.mkDefault "batch";
  nix.daemonIOSchedClass = lib.mkDefault "idle";
  nix.daemonIOSchedPriority = lib.mkDefault 7;
  # https://wiki.nixos.org/wiki/Maintainers:Fastly#Cache_v2_plans
  #nix.binaryCaches = [ "https://aseipp-nix-cache.global.ssl.fastly.net" ];
  #services.swapspace.enable = true;
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
    #    FIXME: unrecognized option '--prefer '^(.firefox-wrappe|java)$''
    #    extraArgs =
    #      let
    #        catPatterns = patterns: lib.concatStringsSep "|" patterns;
    #        preferPatterns = [
    #          ".firefox-wrapped"
    #          "java" # If it's written in java it's uninmportant enough it's ok to kill it
    #        ];
    #        avoidPatterns = [
    #          "bash"
    #          "zsh"
    #          "sshd"
    #          "systemd"
    #          "systemd-logind"
    #          "systemd-udevd"
    #        ];
    #      in
    #      [
    #        "--prefer '^(${catPatterns preferPatterns})$'"
    #        "--avoid '^(${catPatterns avoidPatterns})$'"
    #      ];
  };
}
