# FIXME(roles): This eventually should get slotted into some sort of 'role' thing
{
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
    ykDomainHosts = [
      "ogre"
      "oxid"
      "oedo-wifi" # FIXME: Generate these based on some setting in nixosConfigurations
      "oath"
      "onus"
      "omen"
      "owls"
    ];
    ykNoDomainHosts = [
      "oath_gitlab"
      cfg.networking.subnets.ogre.wildcard
    ]
    ++ lib.optional cfg.isWork secrets.work.git.servers;
  };
  programs.ssh.matchBlocks =
    let
      ogreSubnetHosts = [
        "ottr"
        "oryx"
        "omen"
        "owls"
      ];
      extraSubnetEntries =
        hosts: subnet:
        hosts
        |> lib.lists.map (host: {
          "${host}" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            match = "host ${host},${host}.${osConfig.hostSpec.domain}";
            hostname = "${host}.${osConfig.hostSpec.domain}";
            user = osConfig.hostSpec.networking.subnets.${subnet}.hosts.${host}.user;
            port = osConfig.hostSpec.networking.subnets.${subnet}.hosts.${host}.sshPort;
          };
        })
        |> lib.attrsets.mergeAttrsList;
    in
    {
      # NOTE: These 2 are nixos config hosts, but still have dedicated entries
      # because of the local forward. Not sure how to deal with that yet.
      "moon" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        localForwards =
          let
            unifi = cfg.networking.ports.tcp.unifi-controller;
          in
          [
            {
              # For unifi-controller web interface
              bind.address = "localhost";
              bind.port = unifi;
              host.address = "localhost";
              host.port = unifi;
            }
          ];
      };

      "ooze" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        # Serial consoles are attached to the server, so use socat to forward
        # them as needed
        localForwards = lib.flatten (
          lib.optionals cfg.isWork (
            lib.map
              (port: {
                bind.address = "localhost";
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

      # FIXME(ssh): Use https://superuser.com/questions/838898/ssh-config-host-match-port
      # to match on port, so I don't need to rely on oath_gitlab by name
      "oath_gitlab" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        host = "oath_gitlab";
        hostname = "oath.${cfg.domain}";
        user = "git";
        port = cfg.networking.ports.tcp.gitlab;
      };

      # Isolated lab network, where IPs overlap all the time
      "lab" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        host = cfg.networking.subnets.lab.wildcard;
        extraOptions = {
          UserKnownHostsFile = "/dev/null";
          StrictHostKeyChecking = "no";
        };
      };
    }
    // (extraSubnetEntries ogreSubnetHosts "ogre");
}
