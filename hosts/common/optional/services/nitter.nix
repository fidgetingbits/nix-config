{
  config,
  # lib,
  # inputs,
  ...
}:
let

  # secretsFolder = builtins.toString inputs.nix-secrets;
  # sopsFolder = secretsFolder + "/sops/";
  servicePort = config.hostSpec.networking.ports.tcp.nitter;
in
{
  services.nitter = {
    enable = true;
    server.port = servicePort;
    redisCreateLocally = false; # Already likely setup by other services. Would be good to somehow actually test this
  };

  services.nginxProxy.services = [
    {
      subDomain = "nit";
      extraDomains = [ "nit.${config.hostSpec.domain}" ];
      port = servicePort;
      ssl = false;
      extraSettings = {
        proxyWebsockets = true;
      };
    }
  ];

  # FIXME: Despite generating sessions.jsonl and the values looking sane I get:
  # ---
  # May 26 05:18:11 ooze systemd[1]: Started Nitter (An alternative Twitter front-end).
  # May 26 05:18:11 ooze nitter[1390252]: [sessions] parsing JSONL account sessions file: /run/credentials/nitter.service/sessi
  # onsFile
  # May 26 05:18:11 ooze nitter[1390252]: fatal.nim(53)            sysFatal
  # May 26 05:18:11 ooze nitter[1390252]: Error: unhandled exception: value out of range: -1 notin 0 .. 9223372036854775807 [Ra
  # ngeDefect]
  # ---
  # Seems due to id in parseSession(), since it uses parseBiggestInt()? Though it shouldn't be -1..
  # Not bothering to continue for now
  sops.secrets = {
    "keys/nitter" = {
      path = config.services.nitter.sessionsFile;
    };
  };

  # NOTE: This was failing with /var/lib/nitter already existing, so just letting it
  # load without for now
  # environment = lib.optionalAttrs config.introdus.impermanence.enable {
  #   persistence = {
  #     "${config.hostSpec.persistFolder}".directories = [
  #       {
  #         directory = "/var/lib/private/nitter";
  #         user = "nobody";
  #         group = "nogroup";
  #         mode = "u=rwx,g=r-x,o=";
  #         # mode = "0700";
  #       }
  #     ];
  #   };
  # };
}
