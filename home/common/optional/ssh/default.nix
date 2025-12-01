{
  inputs,
  lib,
  config,
  ...
}:
let
  # There are a subset of hosts where yubikey is used for authentication. An ssh config entry is constructed for each
  # of these hosts that roughly follows the same pattern. Some of these hosts use a domain suffix, so build a list of
  # all hosts with and without domains
  yubikeyHostsWithDomain = [
    "ogre"
    "onyx"
    "oedo"
    "oath"
    "omen"
    "owls"
    "onus"
    "oxid"
    "ooze"
    "oppo"
    "moon"
    "myth"
    "moth"
  ]
  ++ inputs.nix-secrets.networking.ssh.yubikeyHostsWithDomain;
  yubikeyHostsWithoutDomain = [
    # FIXME: These could be automated by having a hostSpec entry that indicates they use boot-time ssh server
    # it could also auto-add the ssh server...
    "myth-backup"
    "myth-unlock"
    "moth-unlock"
    "ooze-unlock"
    "oedo-unlock"
    "oppo-unlock"
    "oath_gitlab" # FIXME(ssh): Would be nice to do per-port match on this, but HM doesn't support
    "okra"
    config.hostSpec.networking.subnets.ogre.wildcard
  ]
  ++ inputs.nix-secrets.networking.ssh.yubikeyHosts;

  # Add domain to each host name
  genDomains = lib.map (h: "${h}.${config.hostSpec.domain}");
  yubikeyHostAll =
    yubikeyHostsWithDomain ++ yubikeyHostsWithoutDomain ++ (genDomains yubikeyHostsWithDomain);
  yubikeyHostsString = lib.concatStringsSep " " yubikeyHostAll;

  # Only a subset of hosts are trusted enough to allow agent forwarding
  forwardAgentHosts = lib.foldl' (acc: b: lib.filter (a: a != b) acc) yubikeyHostsWithDomain (
    [ ] ++ inputs.nix-secrets.networking.ssh.forwardAgentUntrusted
  );
  forwardAgentHostsString = lib.concatStringsSep " " (
    forwardAgentHosts ++ (genDomains forwardAgentHosts)
  );

  # Super keys are yubikeys that have access to every host
  yubikeyPath = "hosts/common/users/super/keys";

  # There is a list of yubikey pubkeys in keys/yubikey. Build a list of
  # corresponding private key files in .ssh
  yubikeys =
    lib.lists.forEach
      (builtins.attrNames (builtins.readDir (lib.custom.relativeToRoot "${yubikeyPath}/")))
      # id_drzt.pub -> id_drzt
      (key: lib.substring 0 (lib.stringLength key - lib.stringLength ".pub") key);
  # FIXME(ssh): Only works if the system supports yubikey (ie: not remote only systems)
  # remote-only servers shouldn't use the id_yubikey mechanism.
  mainKey = [
    "id_yubikey" # This is a special symlink to whatever yubikey is plugged in
  ];
  # FIXME(ssh):
  # - Once I support the id_yubikey link on darwin, I can remove this
  # - We should introduce an option so each host can specify which keys to use as their main key
  identityFiles = if config.hostSpec.hostName == "orby" then yubikeys ++ [ "id_orby" ] else mainKey;

  # NOTE: Yubikey pub keys are purposefully not in .ssh/ root, otherwise they're picked up by ssh-agent, and
  # will used before manual password login or other keys, which can sometimes exhaust the maximum number
  # of authentication attempts
  yubikeyPublicKeyEntries = lib.attrsets.mergeAttrsList (
    lib.lists.map (key: {
      ".ssh/yubikeys/${key}.pub".source = lib.custom.relativeToRoot "${yubikeyPath}/${key}.pub";
    }) yubikeys
  );

  # Lots of hosts have the same default config, so don't duplicate
  vanillaHosts = [
    "ogre"
    "oath"
    "oxid"
    "onus"
    "oedo"
    "onyx"
    "oppo"
    "okra"
    "moth"
  ];
  # FIXME: A lot of hosts have the same properties, but different username, so we
  # should modify this to pass the port for each host, and then we can reduce a lot
  # of noise. We could probably also just use a flag for yubikey and copy a bunch of them.
  # If we do that we should just use options and modularize more of it
  vanillaHostsConfig =
    vanillaHosts
    |> lib.lists.map (host: {
      "${host}" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        match = "host ${host},${host}.${config.hostSpec.domain}";
        hostname = "${host}.${config.hostSpec.domain}";
        port = config.hostSpec.networking.ports.tcp.ssh;
      };
    })
    |> lib.attrsets.mergeAttrsList;

  # Generate an remote unlock entry for every host we have that uses ssh in initrd
  unlockableHostsConfig =
    inputs.self.nixosConfigurations
    |> lib.filterAttrs (name: host: host.config.services.remoteLuksUnlock.enable or false)
    |> lib.attrNames
    |> lib.lists.map (host: {
      "${host}-unlock" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
        host = "${host}-unlock";
        hostname = "${host}.${config.hostSpec.domain}";
        user = "root";
        port = config.hostSpec.networking.ports.tcp.ssh;
        extraOptions = {
          UserKnownHostsFile = "/dev/null";
          StrictHostKeyChecking = "no";
        };
      };
    })
    |> lib.attrsets.mergeAttrsList;
in
{
  programs.ssh =
    let
      workConfig = if config.hostSpec.isWork then ''Include config.d/work'' else "";
    in
    {
      enable = true;

      matchBlocks =
        let
          workHosts = if config.hostSpec.isWork then inputs.nix-secrets.work.git.servers else "";
        in
        {
          # Only try to use yubikey for hosts that support it
          "yubikey-hosts" = lib.hm.dag.entryAfter [ "*" ] {
            host = "${workHosts} ${yubikeyHostsString}";
            identitiesOnly = true;
            identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
          };

          # Only forward agent to hosts that need it
          "forward-agent-hosts" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = forwardAgentHostsString;
            forwardAgent = true;
          };

          "git" = {
            host = "github.com gitlab.com";
            user = "git";
            # NOTE: not included above because we may need to supply a token when using iso, etc. Also don't want to forward
            # the agent to git servers.
            identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
          };

          # NOTE: If these are in vanillaHosts then with an extra user entry it doesn't get added
          "moon" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "moon";
            hostname = "moon.${config.hostSpec.domain}";
            user = "admin";
            port = config.hostSpec.networking.ports.tcp.ssh;
            localForwards =
              let
                unifi = config.hostSpec.networking.ports.tcp.unifi-controller;
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

          # FIXME: These should just be automated via vanilla by querying primaryUsername from the host instead of setting default user to my user...
          "myth" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "myth";
            hostname = "myth.${config.hostSpec.domain}";
            user = "admin";
            port = config.hostSpec.networking.ports.tcp.ssh;
          };

          # Backup dns entry in fact ddclient screws up
          # FIXME: Should script these entries probably
          "myth-backup" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "myth-backup";
            hostname = config.hostSpec.networking.domains.myth-backup;
            user = "root";
            port = config.hostSpec.networking.ports.tcp.gitlab;
            extraOptions = {
              UserKnownHostsFile = "/dev/null";
              StrictHostKeyChecking = "no";
            };
          };

          # FIXME(ssh): Use https://superuser.com/questions/838898/ssh-config-host-match-port
          # to match on port, so I don't need to rely on oath_gitlab by name
          "oath_gitlab" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "oath_gitlab";
            hostname = "oath.${config.hostSpec.domain}";
            user = "git";
            port = config.hostSpec.networking.ports.tcp.gitlab;
          };

          "omen" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "omen";
            hostname = "omen.${config.hostSpec.domain}";
            user = config.hostSpec.networking.subnets.ogre.hosts.omen.user;
            port = config.hostSpec.networking.ports.tcp.ssh;
          };

          "owls" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "owls";
            hostname = "owls.${config.hostSpec.domain}";
            user = config.hostSpec.networking.subnets.ogre.hosts.owls.user;
            port = config.hostSpec.networking.ports.tcp.ssh;
          };

          "oryx" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "oryx";
            hostname = "oryx.${config.hostSpec.domain}";
            user = config.hostSpec.networking.subnets.ogre.hosts.oryx.user;
            port = 22;
          };

          "ottr" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "ottr";
            hostname = "ottr.${config.hostSpec.domain}";
            user = config.hostSpec.networking.subnets.ogre.hosts.ottr.user;
            port = 22;
          };

          "ooze" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = "ooze";
            hostname = "ooze.${config.hostSpec.domain}";
            port = config.hostSpec.networking.ports.tcp.ssh;
            # Serial consoles are attached to the server, so use socat to forward them as needed
            localForwards = lib.flatten (
              lib.optionals config.hostSpec.isWork (
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

          # Isolated lab network, where IPs overlap all the time
          "lab" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            host = config.hostSpec.networking.subnets.lab.wildcard;
            extraOptions = {
              UserKnownHostsFile = "/dev/null";
              StrictHostKeyChecking = "no";
            };
          };

          # FIXME: Revisit this, just moving for 25.11 deprecations
          # We ideally want this to be the last entry
          "*" = lib.hm.dag.entryAfter [ "yubikey-hosts" ] {
            # FIXME(ssh): Control path stuff should probably be for a limited set of systems only?
            controlMaster = "auto";
            controlPath = "${config.home.homeDirectory}/.ssh/sockets/S.%r@%h:%p";
            controlPersist = "60m";
            # Avoids infinite hang if control socket connection interrupted. ex: vpn goes down/up
            serverAliveCountMax = 3;
            serverAliveInterval = 5; # 3 * 5s
            hashKnownHosts = true;
            addKeysToAgent = "yes";

            # NOTE: Work entries are encrypted and added via extraConfig for now
            extraOptions = ''
              SetEnv TERM=xterm-256color
              UpdateHostKeys ask
              ${workConfig}
            '';

          };
        }
        // (inputs.nix-secrets.networking.ssh.matchBlocks lib)
        // unlockableHostsConfig
        // vanillaHostsConfig;
    };

  home.file = {
    ".ssh/config.d/.keep".text = "# Managed by Home Manager";
    ".ssh/sockets/.keep".text = "# Managed by Home Manager";
  }
  // yubikeyPublicKeyEntries;
}
