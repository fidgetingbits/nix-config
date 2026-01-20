{
  pkgs,
  lib,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: rec {
  pname = "git-worktree-add";
  version = "0.0.1-unstable-2026-01-20";
  perHostLocks = false;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase =
    let
      script = pkgs.writeShellApplication {
        name = "git-worktree-add";
        runtimeInputs = lib.attrValues {
          inherit (pkgs)
            git
            ;

        };
        text = lib.readFile ./worktree-add.sh;
      };
    in
    ''
      runHook preInstall
      install -Dm755 ${lib.getExe script} $out/bin/${script.meta.mainProgram}
      runHook postInstall
    '';

  meta = {
    mainProgram = pname;
    maintainers = [ "fidgetingbits" ];
  };
})
