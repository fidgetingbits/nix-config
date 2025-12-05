{
  inputs,
  pkgs,
  lib,
  ...
}:
# To add:
# https://wordshub.github.io/free-font/font.html
# Bopomofo fonts: https://www.mamababymandarin.com/free-chinese-fonts-with-pinyin-and-zhuyin/
# https://www.fonts.net.cn/font-31468148996.html
# ButTaiwan fonts: https://github.com/ButTaiwan?tab=repositories
# Traditional fonts from: https://www.freechinesefont.com/category/traditional-chinese/
# shadowrz fonts:https://github.com/nix-community/nur-combined/blob/main/repos/shadowrz/pkgs/maoken-assorted-sans/default.nix#L28
# https://github.com/mimvoid/nur-pkgs/blob/7a93f0e9615ae291320185eae04e30ca0b1cbc18/pkgs/fonts/ma-shan-zheng/default.nix#L34
# See if there is some way to set the default font at start time to see if you could randomize chinese subtitles from some subset to practice
# TODO:
# Setup https://github.com/hugolpz/Add-Zhuyin for on the fly font conversion on open tab (netflix subtitles, etc)
let
  chineseSansDefaults = [
    "Source Han Sans TC"
    "Source Han Sans SC"
  ];
  chineseSerifDefaults = [
    "Source Han Serif TC"
    "Source Han Serif SC"
  ];
  wang-han-zong-zhong-kai-ti-zhu-yin-regular = pkgs.stdenv.mkDerivation {
    pname = "wang-han-zong-zhong-kai-ti-zhu-yin-regular";
    version = "0-unstable-2025-06-26";

    src = pkgs.fetchurl {
      url = "https://github.com/wordshub/free-font/raw/master/assets/font/%E4%B8%AD%E6%96%87/%E7%8E%8B%E6%B1%89%E5%AE%97%E5%AD%97%E4%BD%93%E7%B3%BB%E5%88%97/%E7%8E%8B%E6%BC%A2%E5%AE%97%E4%B8%AD%E6%A5%B7%E9%AB%94%E6%B3%A8%E9%9F%B3.ttf";
      hash = "sha256-mTLXn9LB/vCM3tHqjz+LMiBuyuV3jWf6wPowwhKXXFA=";
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm644 $src -t $out/share/fonts/truetype
      runHook postInstall
    '';

    meta = {
      description = "A traditional Chinese font from Wordshub";
      homepage = "https://wordshub.github.io/free-font/font.html?WangHanZongZhongKaiTiZhuYin_Regular";
      license = lib.licenses.ofl;
      platforms = lib.platforms.all;
      maintainers = [ lib.maintainers.fidgetingbits ];
    };
  };

  wang-han-zong-zhong-ming-ti-zhu-yin-regular = pkgs.stdenv.mkDerivation {
    pname = "wang-han-zong-zhong-ming-ti-zhu-yin-regular";
    version = "0-unstable-2025-06-26";

    src = pkgs.fetchurl {
      url = "https://github.com/wordshub/free-font/raw/master/assets/font/%E4%B8%AD%E6%96%87/%E7%8E%8B%E6%B1%89%E5%AE%97%E5%AD%97%E4%BD%93%E7%B3%BB%E5%88%97/%E7%8E%8B%E6%BC%A2%E5%AE%97%E4%B8%AD%E6%98%8E%E9%AB%94%E6%B3%A8%E9%9F%B3.ttf";
      hash = "sha256-QQPCuxqzRclge2Aie8V7+Q7r41gAdVSYQQyqTk0w2PY=";
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm644 $src -t $out/share/fonts/truetype
      runHook postInstall
    '';

    meta = {
      description = "A traditional Chinese font from Wordshub";
      homepage = "https://wordshub.github.io/free-font/font.html?WangHanZongZhongMingTiZhuYin_Regular";
      license = lib.licenses.ofl;
      platforms = lib.platforms.all;
      maintainers = [ lib.maintainers.fidgetingbits ];
    };
  };

  wang-han-zong-zhong-ming-ti-fan = pkgs.stdenv.mkDerivation {
    pname = "wang-han-zong-zhong-ming-ti-fan";
    version = "0-unstable-2025-06-26";

    src = pkgs.fetchurl {
      url = "https://github.com/wordshub/free-font/raw/master/assets/font/%E4%B8%AD%E6%96%87/%E7%8E%8B%E6%B1%89%E5%AE%97%E5%AD%97%E4%BD%93%E7%B3%BB%E5%88%97/%E7%8E%8B%E6%BC%A2%E5%AE%97%E4%B8%AD%E6%98%8E%E9%AB%94%E7%B9%81.ttf";
      hash = "sha256-iX78kqtH5k7OOXc3EKOAK8eNiLUXHaFkHdHeUBAO+88=";
    };
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      install -Dm644 $src -t $out/share/fonts/truetype
      runHook postInstall
    '';

    meta = {
      description = "A traditional Chinese font from Wordshub";
      homepage = "https://wordshub.github.io/free-font/font.html?WangHanZongZhongMingTiFan_Regular";
      license = lib.licenses.ofl;
      platforms = lib.platforms.all;
      maintainers = [ lib.maintainers.fidgetingbits ];
    };
  };

  liu-jian-mao-cao = pkgs.stdenv.mkDerivation {
    pname = "liu-jian-mao-cao";
    version = "0-unstable-2025-06-26";

    src = "${inputs.nix-assets}/fonts/liu-jian-mao-cao.zip";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.unzip ];

    installPhase = ''
      runHook preInstall
      unzip $src
      install -Dm644 *.ttf -t $out/share/fonts/truetype
      runHook postInstall
    '';

    meta = {
      description = "A handwriting-style Chinese font from Google Fonts";
      homepage = "https://fonts.google.com/specimen/Liu+Jian+Mao+Cao";
      license = lib.licenses.ofl;
      platforms = lib.platforms.all;
      maintainers = [ lib.maintainers.fidgetingbits ];
    };
  };

  # Fonts with Bopomofo (Zhuyin) support
  bopomofoFonts = [
    wang-han-zong-zhong-ming-ti-zhu-yin-regular
    wang-han-zong-zhong-kai-ti-zhu-yin-regular
  ];

  chineseFonts =
    lib.attrValues {
      inherit (pkgs)
        noto-fonts-cjk-sans
        source-han-sans
        source-han-serif

        eduli # TW MOE Clerical font
        ttf-tw-moe # TW MOE Song/Kai fonts
        ;
    }
    ++ [
      liu-jian-mao-cao
      wang-han-zong-zhong-ming-ti-fan
    ];
in
{
  fonts = {
    # WARNING: Disabling enableDefaultPackages will mess up fonts on sites like
    # https://without.boats/blog/pinned-places/ with huge gaps after the ' character
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = (
      lib.attrValues {
        inherit (pkgs)
          # icon fonts
          material-design-icons
          font-awesome

          noto-fonts
          noto-fonts-color-emoji
          # noto-fonts-extra

          source-sans
          source-serif

          meslo-lgs-nf
          julia-mono
          dejavu_fonts
          ;
        inherit (pkgs.unstable.nerd-fonts)
          fira-code
          iosevka
          jetbrains-mono
          symbols-only
          ;
      }
      ++ chineseFonts
      ++ bopomofoFonts
    );

    # the reason there's Noto Color Emoji everywhere is to override DejaVu's
    # B&W emojis that would sometimes show instead of some Color emojis
    fontconfig.defaultFonts = {
      serif = chineseSerifDefaults ++ [
        "Noto Color Emoji"
        "Iosevka Nerd Font Mono"
        "MesloLGS NF"
        "Nerd Fonts Symbols Only"
        "FiraMono Nerd Font Mono"
      ];
      sansSerif = chineseSansDefaults ++ [
        "Noto Color Emoji"
        "Iosevka Nerd Font Mono"
        "MesloLGS NF"
        "Nerd Fonts Symbols Only"
        "FiraMono Nerd Font Mono"
      ];
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Color Emoji"
        "Iosevka Nerd Font Mono"
        "MesloLGS NF"
        "Nerd Fonts Symbols Only"
        "FiraMono Nerd Font Mono"
      ];
      emoji = [
        "Noto Color Emoji"
        "Nerd Fonts Symbols Only"
      ];
    };
  };
}
