# Development utilities I want across all systems
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  publicGitEmail = config.hostSpec.email.git;
  sshFolder = "${config.home.homeDirectory}/.ssh";
  publicKey =
    if config.hostSpec.useYubikey then "${sshFolder}/id_yubikey.pub" else "${sshFolder}/id_ed25519.pub";
  privateGitConfig = "${config.home.homeDirectory}/.config/git/gitconfig.private";
  workEmail = inputs.nix-secrets.email.work;
  workGitConfig = "${config.home.homeDirectory}/.config/git/gitconfig.work";
  workGitUrlsTable = lib.optionalAttrs config.hostSpec.isWork (
    builtins.listToAttrs (
      map (url: {
        name = "ssh://git@${url}";
        value = {
          insteadOf = "https://${url}";
        };
      }) (lib.splitString " " inputs.nix-secrets.work.git.servers)
    )
  );
in
{
  imports = lib.custom.scanPaths ./.;

  # FIXME: Some of the reversing stuff, etc can likely be moved
  home.packages = lib.flatten [
    (
      builtins.attrValues {
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
      builtins.attrValues {
        inherit (pkgs)
          gdb
          #pwndbg
          gef
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

  programs.git = {
    userName = config.hostSpec.handle;
    userEmail = config.hostSpec.email.git;

    # Enforce SSH to leverage yubikey
    extraConfig = {
      # NOTE: This is way too spammy when looking at repo logs with untrusted keys
      # log.showSignature = "true";
      init.defaultBranch = "main";
      pull.rebase = "true";

      # Don't warn on empty git add calls. Because of "git re-commit" automation
      advice.addEmptyPathspec = false;
      url = lib.optionalAttrs config.hostSpec.isWork (
        lib.recursiveUpdate {
          "ssh://git@${inputs.nix-secrets.work.git.serverMain}" = {
            insteadOf = "https://${inputs.nix-secrets.work.git.serverMain}";
          };
        } workGitUrlsTable
      );

      includeIf."gitdir:${config.home.homeDirectory}/dev/".path = privateGitConfig;
      includeIf."gitdir:${config.home.homeDirectory}/source/".path = privateGitConfig;
      includeIf."gitdir:${config.home.homeDirectory}/work/".path = workGitConfig;
      includeIf."gitdir:${config.home.homeDirectory}/persist/work/".path = workGitConfig;
      diff.tool = "difftastic";
      difftool = {
        prompt = "false";
        difftastic.cmd = "difft \"$LOCAL\" \"$REMOTE\"";
      };
      commit.gpgsign = "true";

      user.signingkey = "${publicKey}";
      gpg = {
        format = "ssh";
        # FIXME: git doesn't support parsing sk-ssh keys, see https://github.com/maxgoedjen/secretive/issues/262
        # See 'alias git' creation in zshrc for how I get around that, while still using signing.key later on
        # sshKeyCommand = "ssh-add -L";

        # Taken from
        # https://github.com/clemak27/homecfg/blob/16b86b04bac539a7c9eaf83e9fef4c813c7dce63/modules/git/ssh_signing.nix#L14
        ssh.allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
      };

    };
    signing = {
      signByDefault = true;
      key = publicKey;
    };
    ignores = [
      ".direnv"
      "result"
    ];
  };

  home.file.".ssh/allowed_signers".text =
    let
      # FIXME: This would need to change if we ever have multiple developer accounts on the same box
      keypath = "hosts/common/users/${config.hostSpec.primaryUsername}/keys/yubikeys/";
      genEmailKeys =
        email: keys:
        lib.concatMapStringsSep "\n" (
          key: "${email} ${lib.fileContents (lib.custom.relativeToRoot "${keypath}/${key}")}\n"
        ) keys;
    in
    ''
      ${genEmailKeys publicGitEmail [
        "id_dade.pub"
        "id_dark.pub"
        "id_drzt.pub"
      ]}
      ${genEmailKeys workEmail [
        "id_dark.pub"
        "id_drzt.pub"
      ]}
    '';
  home.file."${privateGitConfig}".text = ''
    [user]
      name = "${config.hostSpec.handle}"
      email = ${publicGitEmail}
  '';
  home.file."${workGitConfig}".text = ''
    [user]
      name = "${config.hostSpec.userFullName}"
      email = "${workEmail}"
  '';

  home.file.".editorconfig".text = ''
    root = true

    [*]
    end_of_line = lf
    insert_final_newline = true
    indent_style = space
    indent_size = 4

    [*.nix]
    indent_style = space
    indent_size = 4

    [*.lua]
    indent_style = space
    indent_size = 2

    [Makefile]
    indent_style = tab
  '';
}
