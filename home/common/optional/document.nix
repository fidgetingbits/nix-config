{
  pkgs,
  lib,
  ...
}:

{
  home.packages =
    (lib.attrValues {
      inherit (pkgs)
        # document editing
        libreoffice # word, excel, etc

        # document conversion
        pandoc
        noto-fonts-cjk-sans
        ;
    })
    ++ [
      (pkgs.texlive.combine {
        inherit (pkgs.texlive)
          scheme-small
          latexmk
          collection-luatex
          collection-xetex
          collection-langcjk
          cjk
          fontspec
          unicode-math
          xecjk
          ctex
          luatexja
          ;
      })
    ];

  programs.zsh.aliases = {
    # Handles Chinese, European characters, etc together fine
    # Add -o output.pdf input.md  to the end
    md2pdf = "pandoc -f markdown+hard_line_breaks --pdf-engine=typst -V mainfont='Liberation Sans' -V CJKmainfont='Noto Sans CJK SC'";
  };
}
