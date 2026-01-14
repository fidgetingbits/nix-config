{
  pkgs,
  lib,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: rec {
  pname = "long-rsync";
  version = "0.0.1-unstable-2025-12-30";
  perHostLocks = false;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  recipients = recipients;
  deliverer = deliverer;

  installPhase =
    let
      _check =
        assert lib.assertMsg (
          finalAttrs.deliverer != null
        ) "long-rsync: deliverer must be set via overrideAttrs";
        assert lib.assertMsg (
          lib.isList finalAttrs.recipients && finalAttrs.recipients != [ ]
        ) "long-rsync: recipients must be a non-empty list";
        true;

      script = pkgs.writeShellApplication {
        name = "long-rsync";
        runtimeInputs = lib.attrValues {
          inherit (pkgs)
            rsync
            openssh
            gnused
            coreutils
            msmtp
            ;

        };
        text =
          lib.seq _check
            # bash
            ''
              RECIPIENTS=''${RECIPIENTS:-${lib.concatStringsSep ", " finalAttrs.recipients}} DELIVERER=''${DELIVERER:-${finalAttrs.deliverer}}
              ${lib.readFile ./long-rsync.sh}
            '';
      };
    in
    ''
      runHook preInstall

      install -Dm755 ${lib.getExe script} $out/bin/${script.meta.mainProgram}

      runHook postInstall
    '';
})
