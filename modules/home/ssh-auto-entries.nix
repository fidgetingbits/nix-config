{
  inputs,
  config,
  osConfig,
  lib,
  secrets,
  ...
}:
let
  cfg = config.sshAutoEntries;
in
{
  options = {
    sshAutoEntries = {
      enable = lib.mkEnableOption "Auto Configure SSH Host Entries";
      vanillaHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "";
      };
      unlockableHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "";
      };
      identityFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ (if cfg.useYubikey then "id_yubikey" else "id_ed25519") ];
        description = "Identity file name to use as default for hosts";
      };
      domain = lib.mkOption {
        type = lib.types.str;
        default = osConfig.hostSpec.domain;
        description = "Common domain of hosts in this config and those administrated by the owner";
        example = "example.com";
      };
      useYubikey = lib.mkOption {
        type = lib.types.bool;
        default = osConfig.hostSpec.useYubikey;
        description = "Whether the host has yubikeys available";
      };
      ykDomainHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Host names that accept yubikey auth, that have a common domain suffix, and that aren't part of this nixos config";
      };
      ykNoDomainHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Host names that accept yubikey auth, that have no common domain suffix, and that aren't part of this nixos config";
      };
      secretMatchBlocks = lib.mkOption {
        type = lib.types.anything;
        default =
          # FIXME: Maybe revisit this
          (secrets.networking.ssh.matchBlocks lib)
          // lib.optionalAttrs osConfig.hostSpec.isWork (secrets.work.ssh.matchBlocks lib);
        description = "Matchblocks from nix-secrets repo that won't be shown in plaintext in the reoo.";
      };
    };
  };

  config =
    let
      nixosHostNames =
        # FIXME: Make this a set of optional suffixes to ignore
        let
          isMinimal =
            host:
            let
              suffixLen = lib.stringLength "Minimal";
              hostLen = lib.stringLength host;
              prefixLen = hostLen - suffixLen;
              prefix = lib.substring prefixLen suffixLen host;
            in
            if (hostLen > suffixLen && prefix != "Minimal") then prefix else null;
        in
        inputs.self.nixosConfigurations
        |> lib.attrNames
        |> lib.filter (name: name != "iso" && (isMinimal name) != null);

      nixosHostsUnlockable =
        (
          inputs.self.nixosConfigurations
          |> lib.filterAttrs (name: host: host.config.services.remoteLuksUnlock.enable or false)
          |> lib.attrNames
        )
        ++ cfg.unlockableHosts;
      nixosHostsUnlockableNames = lib.lists.map (host: "${host}-unlock") nixosHostsUnlockable;

      # There are a subset of hosts where yubikey is used for authentication.
      # A yubikey-supported ssh config entry is constructed for each host some with
      # domains and some without.
      ykDomainHosts =
        cfg.ykDomainHosts # Configured entries
        ++ nixosHostNames # Auto-generated entries
        ++ secrets.networking.ssh.ykDomainHosts; # Secret entries
      ykNoDomainHosts =
        cfg.ykDomainHosts # Configured entries
        ++ nixosHostsUnlockableNames # Auto-generated unlock entries
        ++ secrets.networking.ssh.ykNoDomainHosts; # Secret entries

      # Add domain to each host name
      genDomains = lib.map (h: "${h}.${cfg.domain}");
      withDomains = hosts: hosts ++ (genDomains hosts);
      ykHosts =
        (withDomains ykDomainHosts) ++ ykNoDomainHosts
        #
        |> lib.concatStringsSep " ";

      # Only a subset of hosts are trusted enough to allow agent forwarding
      forwardAgentHosts =
        secrets.networking.ssh.forwardAgentUntrusted
        |> lib.foldl' (acc: b: lib.filter (a: a != b) acc) ykDomainHosts;

      forwardAgentHostsString =
        withDomains forwardAgentHosts
        #
        |> lib.concatStringsSep " ";

      # Super keys are yubikeys that have access to every host
      yubikeyPath = "hosts/common/users/super/keys";

      # There is a list of yubikey pubkeys in keys/yubikey. Build a list of
      # corresponding private key files in .ssh
      yubikeys =
        lib.lists.forEach
          (
            "${yubikeyPath}/"
            |> lib.custom.relativeToRoot
            |> builtins.readDir
            # nixfmt hack
            |> lib.attrNames
          )
          # id_drzt.pub -> id_drzt
          (key: lib.substring 0 (lib.stringLength key - lib.stringLength ".pub") key);

      vanillaHosts = cfg.vanillaHosts ++ nixosHostNames;

      vanillaHostsConfig =
        vanillaHosts
        |> lib.lists.map (host: {
          "${host}" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            match = "host ${host},${host}.${osConfig.hostSpec.domain}";
            hostname = "${host}.${osConfig.hostSpec.domain}";
            port = osConfig.hostSpec.networking.ports.tcp.ssh;
            # FIXME: Fix the default name later
            user = inputs.self.nixosConfigurations.${host}.osConfig.hostSpec.primaryUsername or "aa";
          };
        })
        |> lib.attrsets.mergeAttrsList;

      # Generate an remote unlock entry for every host we have that uses ssh in initrd
      unlockableHostsConfig =
        nixosHostsUnlockable
        |> lib.lists.map (host: {
          "${host}-unlock" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "${host}-unlock";
            hostname = "${host}.${osConfig.hostSpec.domain}";
            user = "root";
            port = osConfig.hostSpec.networking.ports.tcp.ssh;
            extraOptions = {
              UserKnownHostsFile = "/dev/null";
              StrictHostKeyChecking = "no";
            };
          };
        })
        |> lib.attrsets.mergeAttrsList;

      identityFiles = lib.lists.forEach cfg.identityFiles (
        file: "${config.home.homeDirectory}/.ssh/${file}"
      );
    in

    lib.mkIf cfg.enable {
      programs.ssh = {
        matchBlocks = {
          # Only forward agent to hosts that need it
          "forward-agent-hosts" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = forwardAgentHostsString;
            forwardAgent = true;
          };

          "git" = {
            host = "github.com gitlab.com codeberg.org git.sr.ht";
            user = "git";
            # NOTE: not included above because we may need to supply a token when using iso, etc. Also don't want to forward
            # the agent to git servers.
            identityFile = identityFiles;
          };

          # FIXME: Revisit this
          "*" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            # FIXME(ssh): Control path stuff should probably be for a limited set of systems only?
            controlMaster = "auto";
            controlPath = "${config.home.homeDirectory}/.ssh/sockets/S.%r@%h:%p";
            controlPersist = "60m";
            # Avoids infinite hang if control socket connection interrupted. ex:
            # vpn goes down/up
            serverAliveCountMax = 3;
            serverAliveInterval = 5; # 3 * 5s
            hashKnownHosts = true;
            addKeysToAgent = "yes";

            extraOptions = {
              SetEnv = "TERM=xterm-256color";
              UpdateHostKeys = "ask";
            };
          };
        }
        // lib.optionalAttrs cfg.useYubikey {
          "yubikey-hosts" = lib.hm.dag.entryAfter [ "*" ] {
            host = ykHosts;
            identitiesOnly = true;
            identityFile = identityFiles;
          };
        }
        // cfg.secretMatchBlocks
        // vanillaHostsConfig
        // unlockableHostsConfig;
      };

      # NOTE: Yubikey .pub files aren't stored in .ssh/ root otherwise they're
      # picked up by ssh-agent, and will used before manual password login or other
      # keys, which can exhaust the maximum number of authentication attempts
      home.file =
        yubikeys
        |> lib.lists.map (key: {
          ".ssh/yubikeys/${key}.pub".source = lib.custom.relativeToRoot "${yubikeyPath}/${key}.pub";
        })
        |> lib.attrsets.mergeAttrsList
        |> lib.optionalAttrs cfg.useYubikey;

    };
}
