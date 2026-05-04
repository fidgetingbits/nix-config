# A locally hosted startpage for the browser.
{
  pkgs,
  ...
}:
let
  dawn = pkgs.fetchFromGitHub {
    owner = "b-coimbra";
    repo = "dawn";
    rev = "34c917c6c55833fa2e90988a92317bcb0983425d";
    hash = "sha256-FrU9bFBmJnSoyrkYxeJxxfMVjDiyCRo4giQeIqZEYWE=";
  };
in
{

  imports = [ ./services/nginx.nix ];

  # With no explicit rules this will make nginx listen on localhost only
  # No SSL certs will make it listen on localhost:80, which is okay.
  # WARNING: On a system hosting actual nginxProxy services, this may be
  # problematic. Current untested.
  networking.granularFirewall.enable = true;
  services.nginx = {
    virtualHosts.localhost = {
      locations."/" = {
        root = dawn;
        extraConfig = ''
          default_type text/html;
        '';
      };
    };
  };
}
