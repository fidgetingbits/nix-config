      # https://mozilla.github.io/policy-templates/
      # Inspiration:
      # - https://github.com/mrjones2014/dotfiles/blob/4ec33c26d4d1c86524006bcd3948a1ca9564ed4e/home-manager/modules/arkenfox.nix#L53
      # - https://discourse.nixos.org/t/declare-firefox-extensions-and-settings/36265/20
      # - https://github.com/gvolpe/nix-config/blob/6feb7e4f47e74a8e3befd2efb423d9232f522ccd/home/programs/browsers/firefox.nix
      # - https://github.com/lucidph3nx/nixos-config/blob/2e42a40cc8d93c25e01dcbe0dacd8de01f4f0c16/modules/home-manager/firefox/default.nix
      # - https://github.com/Kreyren/nixos-config/blob/bd4765eb802a0371de7291980ce999ccff59d619/nixos/users/kreyren/home/modules/web-browsers/firefox/firefox.nix#L116-L148
      # - https://github.com/GovanifY/navi/blob/master/components/headfull/graphical/browser.nix
      # https://github.com/michalrus/dotfiles/blob/144ba9849ce9d22e1754b79c1eef28220b377148/machines/lenovo-x1/features/hardened-firefox/default.nix#L157
      # FIXME(firefox):
      # - Tons of settings above I haven't looked into
      # - Setup a separate work profile?
      # - Port bookmarks and other profile settings over from existing profile
      # - Should check ~/.mozilla/firefox/PROFILE_NAME/prefs.js | user.js
      #   from your old profiles too

## Extension Settings

The `~/.mozilla/firefox/<profile>/browser-extension-data/` folder holds the extensions and their associated `storage.js` files, which are json files holding the settings. For instance:

```bash
❯ ls browser-extension-data
78272b6fa58f4a1abaac99321d503a20@proton.me  redirector@einaregilsson.com  {73a6fe31-595d-460b-a920-fcc0f8843232}
addon@darkreader.org                        uBlock0@raymondhill.net
```

After a fresh build we can see that the nix settings:

```nix
                  "{73a6fe31-595d-460b-a920-fcc0f8843232}".settings =
                    let
                      trusted = [
                        "github.com"
                        "nixos.org"
                      ];
                    in
                    {
                      # Add a section sign (§) to the beginning of each trusted site
                      policy.sites.trusted = builtins.map (site: "§:" + site) trusted;
                    };
```

All of these settings get wiped out after you manually change any actual settings in the noscript extension though.
