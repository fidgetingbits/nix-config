{ inputs, pkgs, ... }:
{
  force = true;
  packages = with inputs.firefox-addons.packages.${pkgs.system}; [
    ublock-origin
    noscript
    proton-pass
    darkreader
    redirector
  ];
  settings = {
    "uBlock0@raymondhill.net".settings = {
      selectedFilterLists = [
        "ublock-filters"
        "ublock-badware"
        "ublock-privacy"
        "ublock-unbreak"
        "ublock-quick-fixes"
      ];
    };
    "redirector@einaregilsson.com".settings = {
      redirects = [
        {
          description = "Redirect to official NixOS wiki";
          exampleUrl = "https://nixos.wiki/wiki/Bootloader";
          exampleResult = "https://wiki.nixos.org/wiki/Bootloader";
          includePattern = "https://nixos.wiki/(wiki/.*)";
          excludePattern = "";
          patternDesc = "Changes the base url to wiki.nixos.org";
          redirectUrl = "https://wiki.nixos.org/$1";
          patternType = "R";
          processMatches = "noProcessing";
          disabled = false;
          grouped = false;
          appliesTo = [ "main_frame" ];
        }
      ];
    };
    # noscript (FIXME: Gets overridden by noscript extension no matter what we put in here)
    "{73a6fe31-595d-460b-a920-fcc0f8843232}".settings =
      let
        trustedSites = [
          "nixos.org"
          "duckduckgo.com"
          "github.com"
          "githubassets.com"
        ];
      in
      {
        policy = {
          sites = {
            # Noscript adds the section sign "§" to the beginning of the site name
            trusted = builtins.map (site: "§:" + site) trustedSites;
            untrusted = [ ];
            custom = { };
          };
        };
      };
  };
}
