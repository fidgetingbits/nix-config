{
  lib,
  pkgs,
  ...
}:
{
  imports = lib.custom.scanPaths ./.;

  # FIXME: Some of the reversing stuff, etc can likely be moved
  home.packages = lib.flatten [
    (
      lib.attrValues {
        inherit (pkgs)
          # Development
          direnv
          act # github workflow runner
          gh # github cli
          glab # gitlab cli
          yq-go # Parser for Yaml and Toml Files, that mirrors jq
          # reversing
          radare2
          binwalk

          # nix
          nixpkgs-review

          # networking
          nmap

          # Diffing
          difftastic

          # serial debugging
          screen
          picocom

          # Standard man pages for linux API
          man-pages
          man-pages-posix

          # rust (global for when browsing public projects)
          cargo
          rust-analyzer
          rustc
          ;
      }
      ++ [ pkgs.unstable.imhex ]
    )

    (lib.optionals pkgs.stdenv.isLinux (
      lib.attrValues {
        inherit (pkgs)
          gdb
          # pwndbg
          # gef
          #bata24-gef
          pe-bear
          #binexport
          #bindiff

          # windows
          clippy
          ;
      }
      # ++ [
      # pkgs.bindiff.override
      # { enableIDA = false; } # NOTE: This requires manual setup if enabled
      # ]
    ))
  ];

  home.file.".editorconfig".text = ''
    root = true

    [*]
    end_of_line = lf
    insert_final_newline = true
    indent_style = space
    indent_size = 4

    [*.nix]
    indent_style = space
    indent_size = 2

    [*.lua]
    indent_style = space
    indent_size = 2

    [Makefile]
    indent_style = tab
  '';
}
