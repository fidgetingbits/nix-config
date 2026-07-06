{
  lib,
  config,
  inputs,
  ...
}:
let
  ports = config.hostSpec.networking.ports;
in
{
  imports = [ inputs.hister.nixosModules.default ];

  services.hister = {
    enable = true;
    port = ports.tcp.hister;
    dataDir = "/var/lib/hister";

    settings = {
      app = {
        title = "Hister";
        subtitle = "Stay awhile and search";
      };
      server = {
        base_url = "https://hister.${config.networking.hostName}.${config.hostSpec.domain}";
      };
      semantic_search = {
        enable = true;
        embedding_endpoint = "http://oedo.${config.hostSpec.domain}:${toString ports.tcp.llama-swap}/v1/embeddings";
        embedding_model = "nomic-embed-text";
        #   dimensions = 768;
        #   maxContextLength = 512;
        #   queryPrefix = "search_query: ";
        #   documentPrefix = "search_document: ";
      };
    };
  };

  environment = lib.optionalAttrs config.introdus.impermanence.enable {
    persistence."${config.hostSpec.persistFolder}" = {
      directories = [ config.services.hister.dataDir ];
    };
  };

  services.nginxProxy.services = [
    {
      subDomain = "hister"; # Creates git.host.domain
      # extraDomains = [ "search.${config.hostSpec.domain}" ];
      port = ports.tcp.hister;
      ssl = false;

      extraLocationSettings = {
        # Needed for search to work
        proxyWebsockets = true;
      };
    }
  ];
}
