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
