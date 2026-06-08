{
  config,
  lib,
  pkgs,
  ...

}:
let
  ports = config.hostSpec.networking.ports;
  translatorPort = ports.tcp.mattermostTranslator;
  mattermostPort = ports.tcp.mattermost;
  slackTranslator = pkgs.writers.writePython3Bin "slack-translator" {
    libraries = with pkgs.python3Packages; [
      requests
      werkzeug
    ];
  } (lib.readFile ./pfsense-slack-translator.py);
  wrappedSlackTranslator = pkgs.symlinkJoin {
    name = "wrappedSlackTranslator";
    paths = [ slackTranslator ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = # bash
      ''
        wrapProgram $out/bin/slack-translator \
          --set MATTERMOST_PORT "${toString mattermostPort}" \
          --set TRANSLATOR_PORT "${toString translatorPort}" \
      '';
  };
in
{
  # Run the micro-translator safely managed under systemd
  systemd.services.slack-payload-translator = {
    description = "Translate pfSense multipart-form notifications to Mattermost Webhook JSON";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${wrappedSlackTranslator}/bin/slack-translator";
      Restart = "always";
      DynamicUser = true;
    };
  };

  services.nginxProxy.services = [
    {
      subDomain = "slack-intercept";
      extraDomains = [
        "slack.com"
        "api.slack.com"
      ];
      port = translatorPort;
      ssl = false;

      # Generated with:
      # openssl req \
      #     -x509 \
      #     -nodes \
      #     -days 3650 \
      #     -newkey rsa:2048 \
      #     -keyout local-snakeoil.key \
      #     -out local-snakeoil.crt \
      #     -subj "/CN=slack.com" -addext "subjectAltName = DNS:slack.com, DNS:api.slack.com, DNS:*.slack.com"
      extraHostSettings = {
        sslCertificate = config.sops.secrets."certs/slack-intercept-cert".path;
        sslCertificateKey = config.sops.secrets."certs/slack-intercept-key".path;
      };

      extraLocationSettings = {
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

          # Useful for debugging
          # access_log /var/log/nginx/slack-intercept-access.log;
          # error_log /var/log/nginx/slack-intercept-error.log info;
        '';
      };
    }
  ];
  sops.secrets = {
    "certs/slack-intercept-key" = {
      owner = config.services.nginx.user;
      group = config.services.nginx.group;
    };
    "certs/slack-intercept-cert" = {
      owner = config.services.nginx.user;
      group = config.services.nginx.group;
    };
  };
}
