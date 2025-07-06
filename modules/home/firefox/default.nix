{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
in
{
  config =
    lib.mkIf config.hostSpec.useWindowManager {
      programs.firefox = {
        enable = true;
        # Refer to https://mozilla.github.io/policy-templates or `about:policies#documentation` in firefox
        policies = {
          AppAutoUpdate = false; # Disable automatic application update
          BackgroundAppUpdate = false; # Disable automatic application update in the background, when the application is not running.
          DisableBuiltinPDFViewer = false;
          DisableFirefoxStudies = true;
          DisableFirefoxAccounts = false; # Enable Firefox Sync
          DisablePocket = true;
          DisableTelemetry = true;
          DisableFeedbackCommands = true;
          # To facilitate proper DNS filtering
          DNSOverHTTPS = {
            Enabled = false;
            Locked = true;
          };
          DontCheckDefaultBrowser = true;
          OfferToSaveLogins = false;
          HttpsOnlyMode = true;
          StartDownloadsInTempDirectory = true; # Avoid failed download clutter
          UserMessaging = {
            ExtensionRecommendations = false;
            SkipOnboarding = true;
          };
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
            EmailTracking = true;
          };
          SearchBar = "unified";
          SearchEngines.Default = "DuckDuckGo";
          ExtensionUpdate = false;
          ExtensionSettings = {
            # Disable built-in search engines
            "amazondotcom@search.mozilla.org" = {
              installation_mode = "blocked";
            };
            "bing@search.mozilla.org" = {
              installation_mode = "blocked";
            };
            "ebay@search.mozilla.org" = {
              installation_mode = "blocked";
            };
            "google@search.mozilla.org" = {
              installation_mode = "blocked";
            };
            #  "*" = {
            #  installation_mode = "blocked";
            #  blocked_install_message = "Install your extensions with Nix";
          };
        };

        profiles =
          let
            commonSettings = {
              "signon.rememberSignons" = false; # Disable built-in password manager
              "browser.compactmode.show" = true;
              "browser.uidensity" = 1; # enable compact mode
              "browser.aboutConfig.showWarning" = false;
              "browser.download.dir" = "${homeDir}/downloads";

              "browser.tabs.firefox-view" = true; # Sync tabs across devices
              "ui.systemUsesDarkTheme" = 1; # force dark theme
              "extensions.pocket.enabled" = false;

              # Remove common fingerprinting vectors
              #"privacy.resistFingerprinting" = true; # https://support.mozilla.org/en-US/kb/firefox-protection-against-fingerprinting
              # Silo cookie storage
              # "privacy.firstparty.isolate" = true; # https://bugzilla.mozilla.org/show_bug.cgi?id=1260931

              # Disable prefetching of pages/sites
              "network.prefetch-next" = false;
              "network.dns.disablePrefetch" = true;
              "network.http.speculative-parallel-limit" = 0;

              # Reduce attack surface by disabling JIT, etc
              # "javascript.options.baselinejit" = false;
              # "javascript.options.ion" = false;
              # "javascript.options.wasm" = false;
              # "javascript.options.asmjs" = false;
              # "webgl.disabled" = true;
            };
          in
          {
            default = {
              id = 0;
              name = "default";
              isDefault = true;
              settings = commonSettings;
              extensions = {
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
              };
            };
          };
      };
    }
    // (
      lib.optionalAttrs pkgs.stdenv.isLinux {
        xdg.mimeApps.defaultApplications = {
          "text/html" = [ "firefox.desktop" ];
          "text/xml" = [ "firefox.desktop" ];
          "x-scheme-handler/http" = [ "firefox.desktop" ];
          "x-scheme-handler/https" = [ "firefox.desktop" ];
        };
      }
      // (lib.mkIf config.hostSpec.isAutoStyled {
        # FIXME(firefox): Combine this with the profile name above automatically
        stylix.targets.firefox.profileNames = [
          "default"
        ];
      })
    );

}
