{
  inputs,
  osConfig,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    inputs.introdus.homeManagerModules.default
    (map lib.custom.relativeToRoot [
      "modules/home/"
    ])
    (lib.custom.scanPathsFilterPlatform ./.)
  ];

  home.packages = lib.attrValues (
    {
      inherit (pkgs)
        eza # ls replacement
        zoxide # cd replacement
        fd # tree-style ls
        procs # ps replacement
        duf # df replacement
        ripgrep # grep replacement
        dust # du replacement
        p7zip # archive
        pstree # tree-style ps
        lsof # list open files
        tealdeer # smaller man pages
        eva # cli calculator
        hexyl # hexdump replacement
        grc # colorize output
        # toybox # decode uuencoded files (conflicts with llvm binutils wrapper)
        fastfetch
        jq # json
        gnupg
        yq-go # yaml
        dig

        findutils # find
        file # file type analysis
        openssh

        # nix utlities
        nix-tree # show nix store contents
        nix-sweep # tool for generation garbage collection root analysis

        libnotify # for notify-send

        # network utilities
        iputils # ping, traceroute, etc

        magic-wormhole # Convenient file transfer
        ;

      inherit (pkgs.introdus)
        jq5 # json5-capable jq
        ;

    }
    // lib.optionalAttrs (osConfig.hostSpec.isProduction) {
      inherit (pkgs.llvmPackages)
        bintools # strings, etc
        ;
    }
    // lib.optionalAttrs (osConfig.hostSpec.isProduction && (!osConfig.hostSpec.isServer)) {
      inherit (pkgs)
        mdcat # Markdown preview in cli
        ;
    }
    // lib.optionalAttrs (osConfig.hostSpec.isProduction && (osConfig.hostSpec.useWindowManager)) {
      inherit (pkgs)
        ##
        # Core GUI Utilities
        ##
        evince # pdf reader
        zathura # pdf reader
        ;

      inherit (pkgs.unstable)
        ##
        # Core GUI Utilities
        ##
        obsidian # note taking
        ;
    }
    // lib.optionalAttrs (osConfig.hostSpec.isProduction && (osConfig.hostSpec.useX11)) {
      inherit (pkgs)
        xsel # X clipboard manager
        ;
    }
  );

  programs = {
    bash.enable = true;
    home-manager.enable = true;
  };
}
