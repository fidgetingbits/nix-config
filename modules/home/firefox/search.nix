{ ... }:
{
  force = true; # Don't complain about clobbering backups
  default = "ddg";
  engines = {
    "Awesome Lists" = {
      urls = [ { template = "https://github.com/search?q=awesome+{searchTerms}&type=repositories"; } ];

      definedAliases = [
        "@awesome"
      ];
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
    "SearXNG" = {
      urls = [ { template = "https://search.inetol.net/search?q={searchTerms}"; } ];

      definedAliases = [
        "@sr"
        "@searx"
      ];
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
  };
}
