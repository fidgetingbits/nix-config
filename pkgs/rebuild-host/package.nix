# Tool used to rebuild the system configuration on a remote host or the local host.
#
# FIXME: I didn't port the BUILD_LOG logic from rebuild.sh since I haven't been using
# it lately.
{
  stdenvNoCC,
  pkgs,
  lib,
  introdus-helpers,
  rsync,
  openssh,
  git,
  nix,
  sops,
  ...
}:
stdenvNoCC.mkDerivation (
  finalAttrs:
  let
    shellScript = pkgs.writeShellApplication {
      name = "rebuild-host";
      runtimeInputs = [
        rsync
        openssh
        git
        nix
        sops
      ];
      runtimeEnv = {
        PER_HOST_LOCKS = lib.boolToString finalAttrs.perHostLocks;
        NIXPKGS_ALLOW_UNFREE = 1;
        NIXPKGS_ALLOW_BROKEN = 1;
        NH_NO_CHECKS = 1; # https://github.com/nix-community/nh/issues/353
        NIX_SSHOPTS = "-p10022"; # FIXME: This should be updated to use secrets now somehow
      };
      text = # bash
        ''
          # shellcheck disable=SC1091
          source "${introdus-helpers}/share/introdus-helpers/helpers.sh"
          HOST="''${1-$(hostname)}"

          reference_lock=()
          if "$PER_HOST_LOCKS"; then
            reference_lock+=("--reference-lock-file" "locks/$HOST.lock")
            trap cleanup_flake_lock EXIT HUP INT QUIT TERM
          fi
          if [ "$HOST" != "$(hostname)" ]; then
            # FIXME: Double check if we can use nh for this?
            nixos-rebuild \
              --target-host "$HOST" \
              --sudo \
              --impure \
              --show-trace \
              --flake .#"$HOST" \
              switch
          else
            nh os switch . -- \
              "''${reference_lock[@]}" \
              --impure \
              --show-trace
          fi

          # shellcheck disable=SC2181
          if [ $? -eq 0 ]; then
            green "====== POST-BUILD ======"
            green "$HOST built successfully"

            # Check for pending local changes that might influence build success
            if git diff --exit-code >/dev/null && git diff --staged --exit-code >/dev/null; then
                # Check if the current commit has a buildable tag
                if git tag --points-at HEAD | grep -q buildable; then
                    yellow "Current commit is already tagged as buildable"
                else
                    git tag "$HOST"-buildable-"$(date +%Y%m%d%H%M%S)" -m ""
                    green "Tagged current commit as buildable on $HOST"
                fi
            else
                yellow "WARN: There are pending changes that would affect the build succeeding. Commit them before tagging"
            fi
          else
            red "Build failed?"
          fi
        '';
    };
  in
  {
    pname = "rebuild-host";
    version = "0.0.1-unstable-2025-12-30";
    perHostLocks = false;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 ${lib.getExe shellScript} $out/bin/${shellScript.meta.mainProgram}

      runHook postInstall
    '';
  }
)
