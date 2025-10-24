# FIXME: We can probably just remove the params fields and simplify with inline {searchTerms} for most of these, to reduce the code size
{ lib, ... }:
let
  icon = "https://search.nixos.org/favicon.png";
in
{
  force = true; # Don't complain about clobbering backups
  default = "ddg";
  engines =
    let
      mkGitHubLangSearch = lang: aliases: {
        "Github ${lang} Language Search" = {
          urls = [
            {
              template = "https://github.com/search";
              params = [
                {
                  name = "q";
                  value = "language:${lang} {searchTerms}";
                }
                {
                  name = "type";
                  value = "code";
                }
              ];
            }
          ];
          inherit icon;
          definedAliases = aliases;
        };
      };
      mkLang = lang: aliases: { inherit lang aliases; };
      # FIXME: Would be nice to have per-lang icons for clearer alias results
      gitHubLangSearches = lib.mergeAttrsList (
        map (entry: mkGitHubLangSearch entry.lang entry.aliases) [
          (mkLang "nix" [ "@nl" ])
          (mkLang "lua" [ "@ll" ])
          (mkLang "shell" [ "@sl" ])
          (mkLang "rust" [ "@rl" ])
          (mkLang "python" [ "@pl" ])
        ]
      );
    in
    {
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
        ];
      };
      "Home Manager Options" = {
        inherit icon;
        urls = [
          {
            template = "https://home-manager-options.extranix.com/";
            params = [
              # FIXME: Add default release probably
              {
                name = "query";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        definedAliases = [
          "@ho"
          "@hmo"
        ];
      };
      "NixOS Wiki" = {
        urls = [
          { template = "https://nixos.wiki/index.php?search={searchTerms}"; }
        ];
        icon = "https://nixos.wiki/favicon.png";
        definedAliases = [ "@nw" ];
      };
      "Lix Wiki" = {
        urls = [
          { template = "https://wiki.lix.systems/search?term={searchTerms}"; }
        ];
        icon = "https://external-content.duckduckgo.com/ip3/lix.systems.ico";
        definedAliases = [ "@lix" ];
      };
      "GitHub Nixpkgs Search" = {
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
        definedAliases = [
          "@npr" # nixpkgs repo
        ];
      };
      "GitHub Home-manager Search" = {
        urls = [
          {
            template = "https://github.com/search";
            params = [
              {
                name = "q";
                value = "repo:nix-community/home-manager language:nix {searchTerms}";
              }
              {
                name = "type";
                value = "code";
              }
            ];
          }
        ];
        inherit icon;
        definedAliases = [
          "@hm"
          "@hmr" # home-manager repo
        ];
      };
      "Noogle" = {
        urls = [
          {
            template = "https://noogle.dev/";
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
      "Nix Reference Manual" = {
        urls = [ { template = "https://nixos.org/manual/nix/unstable/?search={searchTerms}"; } ];

        definedAliases = [
          "@nm"
          "@nixman"
          "@nixmanual"
        ];
        inherit icon;
      };
      "Nixpkgs Tracker" = {
        urls = [ { template = "https://nixpkgs-tracker.ocfox.me/?pr={searchTerms}"; } ];

        definedAliases = [
          "@nixpkgstracker"
          "@nixtrack"
          "@nixprtracker"
        ];
      };
      "Nix Discourse" = {
        urls = [ { template = "https://discourse.nixos.org/search?q={searchTerms}"; } ];
        definedAliases = [ "@nd" ];
      };

      "Unix Porn" = {
        urls = [
          {
            template = "https://www.reddit.com/r/unixporn/search";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
              {
                name = "type";
                value = "code";
              }
            ];
          }
        ];
        icon = "https://styles.redditmedia.com/t5_2sx2i/styles/communityIcon_7fixeonxbxd41.png";
        definedAliases = [ "@up" ];
      };
      "GitHub Search" = {
        urls = [
          {
            template = "https://github.com/search";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        icon = "https://github.githubassets.com/favicons/favicon.png";
        definedAliases = [ "@gh" ];
      };
      "Awesome Lists" = {
        urls = [ { template = "https://github.com/search?q=awesome+{searchTerms}&type=repositories"; } ];

        definedAliases = [
          "@awesome"
        ];
      };
      "Man Pages" = {
        urls = [ { template = "https://man.archlinux.org/search?q={searchTerms}"; } ];
        definedAliases = [ "@man" ];
      };
      "Wayback Machine" = {
        urls = [ { template = "https://web.archive.org/web/*/{searchTerms}"; } ];
        definedAliases = [ "@wayback" ];
      };
      "IMDB" = {
        urls = [ { template = "https://www.imdb.com/find?s=all&q={searchTerms}"; } ];

        definedAliases = [ "@imdb" ];
      };
      "Dictionary" = {
        urls = [ { template = "https://dictionary.reference.com/browse/{searchTerms}"; } ];

        definedAliases = [ "@dict" ];
      };
      "Google Translate" = {
        urls = [
          {
            template = "https://translate.google.com/?#auto|auto|{searchTerms}";
          }
        ];

        definedAliases = [ "@gootr" ];
      };
      "Arch Wiki" = {
        urls = [ { template = "https://wiki.archlinux.org/index.php?search={searchTerms}"; } ];

        definedAliases = [ "@aw" ];
      };
      "reddit" = {
        urls = [ { template = "https://www.reddit.com/search/?q={searchTerms}"; } ];

        definedAliases = [
          "@reddit"
        ];
      };
      "GitLab" = {
        urls = [
          {
            template = "https://gitlab.com/search";
            params = [
              {
                name = "search";
                value = "{searchTerms}";
              }
            ];
          }
        ];

        definedAliases = [ "@gl" ];
      };
      "SourceHut" = {
        urls = [ { template = "https://sr.ht/projects?search={searchTerms}"; } ];

        definedAliases = [
          "@sourcehut"
          "@srht"
        ];
      };
      "MDN" = {
        urls = [ { template = "https://developer.mozilla.org/en-US/search?q={searchTerms}"; } ];

        definedAliases = [ "@mdn" ];
      };

      "Python Docs" = {
        urls = [ { template = "https://docs.python.org/3/search.html?q={searchTerms}"; } ];

        definedAliases = [ "@pydocs" ];
      };

      "crates.io" = {
        urls = [ { template = "https://crates.io/search?q={searchTerms}"; } ];

        definedAliases = [ "@crates" ];
      };
      "Rust Std" = {
        urls = [ { template = "https://doc.rust-lang.org/std/?search={searchTerms}"; } ];

        definedAliases = [
          "@rstd"
        ];
      };
      "Rust Language Documentation" = {
        urls = [ { template = "https://doc.rust-lang.org/std/?search={searchTerms}"; } ];

        definedAliases = [
          "@rust"
        ];
      };
      "Rust Crates Documentation" = {
        urls = [ { template = "https://docs.rs/releases/search?query={searchTerms}"; } ];

        definedAliases = [
          "@drs"
          "@docsrs"
        ];
      };
      "Lib.rs" = {
        urls = [ { template = "https://lib.rs/search?q={searchTerms}"; } ];

        definedAliases = [
          "@lrs"
          "@librs"
        ];
      };
      "youtube" = {
        urls = [ { template = "https://www.youtube.com/results?search_query={searchTerms}"; } ];

        definedAliases = [
          "@youtube"
          "@yt"
        ];
      };
      "Twitter" = {
        urls = [ { template = "https://twitter.com/search?q={searchTerms}"; } ];

        definedAliases = [
          "@twitter"
          "@x"
          "@tw"
        ];
      };
      "SearXNG" = {
        urls = [ { template = "https://search.inetol.net/search?q={searchTerms}"; } ];

        definedAliases = [
          "@sr"
          "@searx"
        ];
      };
      "AlternativeTo" = {
        urls = [ { template = "https://alternativeto.net/browse/search?q={searchTerms}"; } ];

        definedAliases = [
          "@alt"
        ];
      };
      "Libgen" = {
        urls = [
          {
            template = "https://www.libgen.is/search.php?req={searchTerms}&lg_topic=libgen&open=0&view=simple&res=25&phrase=1&column=def";
          }
        ];

        definedAliases = [ "@libgen" ];
      };
      "Hanzicraft" = {
        urls = [ { template = "https://hanzicraft.com/character/{searchTerms}"; } ];
        definedAliases = [ "@hc" ];
      };
      "wikipedia".metaData.hidden = true;
      "google".metaData.hidden = true;
      "amazondotcom-us".metaData.hidden = true;
      "bing".metaData.hidden = true;
      "ebay".metaData.hidden = true;
    }
    // gitHubLangSearches;
}
