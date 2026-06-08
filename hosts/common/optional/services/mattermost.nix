{
  config,
  lib,
  pkgs,
  ...
}:
let
  servicePort = config.hostSpec.networking.ports.tcp.mattermost;
  dbUri = "postgres://mattermost@/mattermost?host=/run/postgresql/";

  mmEnvFile = pkgs.writeText "mattermost-env" ''
    MM_SQLSETTINGS_DRIVERNAME=postgres
    MM_SQLSETTINGS_DATASOURCE=${dbUri}
  '';

  translatorPort = 8066;

  slackTranslator = pkgs.writers.writePython3Bin "slack-translator" { } ''
    # flake8: noqa
    import urllib.request
    import json
    import sys
    from email.parser import BytesFeedParser
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class TranslateHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            content_type = self.headers.get('Content-Type')
            content_length = int(self.headers.get('Content-Length', 0))

            raw_body = self.rfile.read(content_length)

            parser = BytesFeedParser()
            ct_bytes = content_type.encode('utf-8')
            parser.feed(b"Content-Type: " + ct_bytes + b"\r\n\r\n")
            parser.feed(raw_body)
            msg = parser.close()

            form_data = {}
            if msg.is_multipart():
                for part in msg.get_payload():
                    name = part.get_param(
                        'name', header='content-disposition'
                    )
                    if name:
                        payload_bytes = part.get_payload(decode=True)
                        form_data[name] = payload_bytes.decode('utf-8').strip()

            token = form_data.get("token", "")
            channel = form_data.get("channel", "")
            text = form_data.get("text", "")

            # --- TELEMETRY LOGS ---
            print(f"--- DEBUG: Incoming Request Parsed ---", file=sys.stderr)
            print(f"Token found: {'Yes' if token else 'No'}", file=sys.stderr)
            print(f"Channel: '{channel}'", file=sys.stderr)
            print(f"Text Payload: '{text}'", file=sys.stderr)
            sys.stderr.flush()
            # ----------------------

            if not token:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"Error: Token parameter missing")
                return

            mm_payload = {
                "text": text or "Empty alert body received from firewall.",
                "channel": channel,
            }

            target_url = f"http://127.0.0.1:${toString servicePort}/hooks/{token}"

            json_bytes = json.dumps(mm_payload).encode('utf-8')

            req = urllib.request.Request(
                target_url,
                data=json_bytes,
                headers={
                    'Content-Type': 'application/json; charset=utf-8',
                    'User-Agent': 'Mattermost-Slack-Translator'
                }
            )

            try:
                with urllib.request.urlopen(req) as response:
                    self.send_response(response.status)
                    self.end_headers()
                    self.wfile.write(response.read())
            except urllib.error.HTTPError as e:
                # Catch and pass back the actual response text from Mattermost
                err_body = e.read().decode('utf-8')
                print(f"Mattermost Rejected Request: {err_body}", sys.stderr)
                self.send_response(e.code)
                self.end_headers()
                self.wfile.write(err_body.encode())
            except Exception as e:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(str(e).encode())

    print("Starting local translation layer...")
    HTTPServer(
        ('127.0.0.1', ${toString translatorPort}), TranslateHandler
    ).serve_forever()
  '';
in
{
  services.mattermost = {
    enable = true;
    siteUrl = "https://chat.${config.hostSpec.domain}";
    siteName = "Fidgeting Chat";
    port = servicePort;
    database = {
      fromEnvironment = true;
      create = false;
      peerAuth = true;
    };
    mutableConfig = true; # FIXME: use mutable for testing stuff
    preferNixConfig = true;
    environmentFile = "${mmEnvFile}";

    # Reference: https://docs.mattermost.com/configure/configuration-settings.html
    settings = {
      TeamSettings = {
        EnableAccountCreation = false; # Only shut this off after creating your first user
        EnableOpenServer = false;
      };
      ServiceSettings = {
        EnableBotAccountCreation = true;
      };
    };
  };

  # Run the micro-translator safely managed under systemd
  systemd.services.slack-payload-translator = {
    description = "Translate pfSense multipart-form notifications to Mattermost Webhook JSON";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${slackTranslator}/bin/slack-translator";
      Restart = "always";
      DynamicUser = true;
    };
  };

  services.nginxProxy.services = [
    {
      subDomain = "chat"; # Creates chat.host.domain
      extraDomains = [
        "chat.${config.hostSpec.domain}"
      ];
      port = servicePort;
      ssl = false;
      extraLocationSettings = {
        proxyWebsockets = true;
      };
    }
    {
      subDomain = "slack-intercept";
      extraDomains = [
        "slack.com"
        "api.slack.com"
      ];
      port = translatorPort;
      ssl = false;

      extraHostSettings = {
        sslCertificate = "/var/lib/nginx/local-snakeoil.crt";
        sslCertificateKey = "/var/lib/nginx/local-snakeoil.key";

      };
      extraLocationSettings = {
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

          access_log /var/log/nginx/slack-intercept-access.log;
          error_log /var/log/nginx/slack-intercept-error.log info;
        '';
      };
    }
  ];

  # NOTE: mattermost tmpfile creation seems to be incompatible with impermanence for some reason? I guess maybe it
  # runs before the impermanence mount, so the created files get hidden? This forces the tmpfile rules to run
  # right before launch, to ensure that they land inside the persistence mount
  # IMPORTANT: You _might_ need to manually run `systemd-tmpfiles --create --prefix=/var/lib/mattermost` once, if
  # your /var/lib/mattermost folder is still empty after the service starts. Just restart it after
  # FIXME: Would be nice to fix this somehow in nixpkgs and PR, maybe by not using systemd.tmpfiles for these folders?
  systemd.services.mattermost = {
    serviceConfig = {
      ExecStartPre = "${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=/var/lib/mattermost";
    };
  };

  environment = lib.optionalAttrs config.introdus.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [
        {
          directory = "/var/lib/mattermost";
          inherit (config.services.mattermost) user group;
          mode = "0750";
        }
      ];
    };
  };
}
