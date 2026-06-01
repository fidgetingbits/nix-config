# FIXME(roles): This eventually should get slotted into some sort of 'role' thing
{
  inputs,
  osConfig,
  lib,
  secrets,
  ...
}:
let
  cfg = osConfig.hostSpec;
in
lib.mkIf cfg.isAdmin {
  sshAutoEntries = {
    enable = true;
    # FIXME: Would be nice if this could be flagged in the subnet attr set instead of manually managed
    ykDomainHosts = [
      "ogre"
      "oxid"
      "oedo-wifi" # FIXME: Generate these wifi-based on some setting in nixosConfigurations
      "oath"
      "onus"
      "omen"
      "owls"
    ];
    ykNoDomainHosts = [
      "oath_gitlab"
      cfg.networking.subnets.olan.wildcard
    ]
    ++ lib.optional cfg.isWork secrets.work.git.servers;
    # Extra git servers that take yubikey auth and user git
    extraGitServers = [
      "git.${cfg.domain}"
      "git.ooze.${cfg.domain}"
    ];
  };

  programs.ssh.settings =
    let
      nixosHostNames =
        inputs.self.nixosConfigurations
        |> lib.attrNames
        |> lib.filter (name: (name != "iso") && (!(lib.hasSuffix "Minimal" name)));

      # ssh-auto-entries already auto-handles any systems in the subnet that
      # have nixosConfigurations entries, so filter out and add an entry for
      # any other non-nix subnet entries. Caveat is it will create entries for
      # anything that isn't running ssh, but that's better than listing it all
      # manually imo
      olanSubnetHosts =
        osConfig.hostSpec.networking.subnets.olan.hosts
        |> lib.attrNames
        |> lib.filter (name: !(lib.elem name nixosHostNames));
      extraSubnetEntries =
        hosts: subnet:
        hosts
        |> lib.lists.map (host: {
          "${host}" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            Match = "host ${host},${host}.${osConfig.hostSpec.domain}";
            Hostname = "${host}.${osConfig.hostSpec.domain}";
            User = osConfig.hostSpec.networking.subnets.${subnet}.hosts.${host}.user;
            Port = osConfig.hostSpec.networking.subnets.${subnet}.hosts.${host}.sshPort;
          };
        })
        |> lib.attrsets.mergeAttrsList;
    in
    {
      # NOTE: These 2 are nixos config hosts, but still have dedicated entries
      # because of the local forward. Not sure how to deal with that yet.
      "moon" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        LocalForward =
          let
            unifi = cfg.networking.ports.tcp.unifi-controller;
          in
          {
            # For unifi-controller web interface
            bind.port = unifi;
            host.address = "localhost";
            host.port = unifi;
          };
      };

      "ooze" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        #   # Serial consoles are attached to the server, so use socat to forward
        #   # them as needed
        LocalForward = lib.flatten (
          lib.optionals cfg.isWork (
            lib.map
              (port: {
                bind.port = port;
                host.address = "localhost";
                host.port = port;
              })
              [
                5000
                5001
                5002
                5003
              ]
          )
        );
      };

      # This is mostly covered by existing git from ssh-auto-entries, but the port differs
      "internal-git" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        Host = "git.${cfg.domain} git.ooze.${cfg.domain}";
        HostName = "git.${cfg.domain}";
        Port = cfg.networking.ports.tcp.ssh;
      };

      "synology-tweaks" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        Host = "oath oath.${cfg.domain} onus onus.${cfg.domain}";
        # Stuck on older versions of ssh, so avoid PQ warning
        WarnWeakCrypto = "no-pq-kex";
        # Fix coloring nonsense
        RemoteCommand = "export LS_COLORS+=':ow=01;34'; /bin/sh -l";
        RequestTTY = "force";
      };

      # Isolated lab network, where IPs overlap all the time
      "lab" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        Host = cfg.networking.subnets.fg-lab.wildcard;
        UserKnownHostsFile = "/dev/null";
        StrictHostKeyChecking = "no";
      };
    }
    // (extraSubnetEntries olanSubnetHosts "olan");
}
