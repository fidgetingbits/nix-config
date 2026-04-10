{
  lib,
  pkgs,
  ...
}:
{
  imports = lib.custom.scanPaths ./.;

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

  # FIXME: This should merge the introdus defaults probably instead of repeating
  home.file.".editorconfig".text = ''
    root = true

    [*]
    end_of_line = lf
    insert_final_newline = true
    indent_style = space
    indent_size = 4
    insert_final_newline = true

    charset = utf-8
    trim_trailing_whitespace = true

    [*.{nix,lua}]
    indent_style = space
    indent_size = 2

    [justfile]
    indent_style = space
    indent_size = 4

    [*.{yaml,yml}]
    indent_style = space
    indent_size = 2

    [*.sh]
    indent_size = 4

    [Makefile]
    indent_style = tab

    [*.{puml.md,puml,iuml,uml,pu,plantuml}]
    indent_size = 2
  '';

  xdg = {
    # Disable pwntools auto-update
    configFile."pwn.conf".text = ''
      [update]
      interval=never
    '';
  };

}
