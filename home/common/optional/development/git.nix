{
  config,
  lib,
  ...
}:
let
  email = config.hostSpec.email;
  sshFolder = "${home}/.ssh";
  home = config.home.homeDirectory;
  publicKey =
    if config.hostSpec.useYubikey then "${sshFolder}/id_yubikey.pub" else "${sshFolder}/id_ed25519.pub";

  handle = config.hostSpec.handle;
  forges = {
    "codeberg.org" = "noreply";
    "github.com" = "users.noreply";
    "gitlab.com" = "users.noreply";
  };
  forgeEmail = forge: prefix: "${handle}@${prefix}.${forge}";

  #  workGitUrlsTable = lib.optionalAttrs config.hostSpec.isWork (
  #    lib.listToAttrs (
  #      map (url: {
  #        name = "ssh://git@${url}";
  #        value = {
  #          insteadOf = "https://${url}";
  #        };
  #      }) (lib.splitString " " secrets.work.git.servers)
  #    )
  #  );
in
{
  programs.git = {
    settings = {
      user = {
        # email = email.git.github;
        name = handle;
        signingkey = "${publicKey}";
      };
      init.defaultBranch = "main";
      pull.rebase = "true";

      # Don't warn on empty git add calls. Because of "git re-commit" automation
      advice.addEmptyPathspec = false;

      # Re-enable when applicable
      #      url = lib.optionalAttrs config.hostSpec.isWork (
      #        lib.recursiveUpdate {
      #          "ssh://git@${secrets.work.git.serverMain}" = {
      #            insteadOf = "https://${secrets.work.git.serverMain}";
      #          };
      #        } workGitUrlsTable
      #      );

      diff.tool = "difftastic";
      difftool = {
        prompt = "false";
        difftastic.cmd = "difft \"$LOCAL\" \"$REMOTE\"";
      };

      commit.gpgsign = "true";
      gpg = {
        format = "ssh";
        # NOTE: git doesn't support parsing sk-ssh keys, see https://github.com/maxgoedjen/secretive/issues/262
        # See 'alias git' creation in zshrc for how I get around that, while still using signing.key later on
        # sshKeyCommand = "ssh-add -L";
        ssh.allowedSignersFile = "${home}/.ssh/allowed_signers";
      };
    };
    includes =
      let
        privateGitConfig = {
          user = {
            name = handle;
            # Email used for any repo when no conditional includes fire
            email = email.git.primary;
          };
        };
        workGitConfig = {
          user = {
            name = config.hostSpec.userFullName;
            email = if (builtins.isList email.work) then lib.elem 0 email.work else email.work;
          };
        };
        devFolders = [
          "${home}/dev/"
          "${home}/source/"
        ];
        workFolders = [
          "${home}/work/"
          "${home}/persist/work/"
        ];
        mapFolders =
          paths: contents:
          lib.map (f: {
            condition = "gitdir:${f}";
            inherit contents;
          }) paths;
        mapRemotes =
          remotes:
          lib.mapAttrsToList (name: value: {
            condition = "hasconfig:remote.*.url:**/*${name}/**";
            contents = {
              user.email = (forgeEmail name value);
            };
          }) remotes;

      in
      # Order matters. Last match wins, so we want granular email changes last
      (mapFolders devFolders privateGitConfig)
      ++ (mapFolders workFolders workGitConfig)
      ++ (mapRemotes forges);

    signing = {
      signByDefault = true;
      key = publicKey;
    };
    ignores = [
      ".direnv"
      "result"
    ];
  };

  # FIXME: This should become something with options probably
  home.file.".ssh/allowed_signers".text =
    let
      # FIXME: This would need to change if we ever have multiple developer
      # accounts on the same box or we have work keys that aren't our own
      # yubikeys, etc
      keypath = "hosts/common/users/super/keys/";
      devEmails = lib.mapAttrsToList (name: value: forgeEmail name value) forges;
      # If email.work is set and not set it to "", returns a list of said emails
      workEmail =
        if (email ? work) then
          if (builtins.isList email.work) then
            email.work
          else
            lib.flatten [
              (lib.filter (n: n != "") [ email.work ])
            ]
        else
          [ ];
      genGitEmailKeys =
        emails: keys:
        lib.concatMapStringsSep "\n" (
          key:
          let
            signers =
              emails
              |> lib.filter (s: s != "")
              # nixfmt hack
              |> lib.concatStringsSep ",";
            keyContent =
              "${keypath}/${key}"
              |> lib.custom.relativeToRoot
              # nixfmt hack
              |> lib.fileContents;
          in
          ''${signers} namespaces="git" ${keyContent}\n''
        ) keys;
    in
    ''
      ${
        genGitEmailKeys devEmails [
          "id_dade.pub"
          "id_dark.pub"
          "id_drzt.pub"
        ]
      };
      ${genGitEmailKeys workEmail [
        "id_dark.pub"
        "id_drzt.pub"
      ]}
    '';

}
