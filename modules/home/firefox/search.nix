{ pkgs, ... }:
let
  icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
in
{
  engines = {
    "Nix Packages" = {
      urls = [
        {
          template = "https://search.nixos.org/packages";
          params = [
            {
              name = "type";
              value = "packages";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      inherit icon;
      definedAliases = [ "@np" ];
    };
    "NixOS Options" = {
      inherit icon;
      urls = [
        {
          template = "https://search.nixos.org/options";
          params = [
            {
              name = "type";
              value = "packages";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];
      definedAliases = [
        "@no"
        "@nixopts"
      ];
    };
    "Home Manager Options" = {
      urls = [ { template = "https://home-manager-options.extranix.com/?query={searchTerms}"; } ];
      # urls = [
      #   {
      #     template = "https://mipmip.github.io/home-manager-option-search";
      #     params = [
      #       {
      #         name = "query";
      #         value = "{searchTerms}";
      #       }
      #     ];
      #   }
      # ];
      definedAliases = [
        "@hm"
        "@home"
        "'homeman"
      ];
      inherit icon;
    };
    "NixOS Wiki" = {
      urls = [
        { template = "https://nixos.wiki/index.php?search={searchTerms}"; }
      ];
      icon = "https://nixos.wiki/favicon.png";
      updateInterval = 86400000;
      definedAliases = [ "@nw" ];
    };
    "Github Nix Language Search" = {
      urls = [
        {
          template = "https://github.com/search";
          params = [
            {
              name = "q";
              value = "language:nix {searchTerms}";
            }
            {
              name = "type";
              value = "code";
            }
          ];
        }
      ];
      inherit icon;
      definedAliases = [ "@ghnl" ];
    };
    "Github Nixpkgs Search" = {
      urls = [
        {
          template = "https://github.com/search";
          params = [
            {
              name = "q";
              value = "repo:nixos/nixpkgs language:nix {searchTerms}";
            }
            {
              name = "type";
              value = "code";
            }
          ];
        }
      ];
      inherit icon;
      definedAliases = [ "@ghnp" ];
    };
    "Noogle" = {
      urls = [
        {
          template = "https://noogle.dev/q";
          params = [
            {
              name = "q";
              value = "term={searchTerms}";
            }
            {
              name = "type";
              value = "code";
            }
          ];
        }
      ];
      inherit icon;
      definedAliases = [ "@ng" ];
    };
  };
}
