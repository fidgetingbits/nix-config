# Orchestrate additional backup mirroring logic for
# non-declarative hosts on o-lan

# This is a wrapper around borg-backup-paths that allows us to backup folders
# from the nas, but from ooze. This allows us to be more declarative,
# at the expense of some extra network ping pong. But I don't want to
# maintain scripts on the NAS itself anymore.
#
# This relies on having the NAS share mounted via cifs/nfs. Otherwise we can
# mostly rely on default settings. Since we are backing up oath, we backup to
# moth instead

{
  config,
  namespace,
  ...
}:
let
in
{
  ${namespace}.backup-external-host = {
    enable = true;
    hosts = [
      rec {
        host = "oath";
        server = "moth";
        # NOTE: this path corresponds to /volume1/shared/ on oath
        mountPath = "/home/${config.hostSpec.primaryUsername}/mount/${host}";
        folders = [
          "art"
          "audio"
          "documents"
          "ebooks"
          # "images" - These are in immich now
          "logs"
          "public"
          # "unsorted"
          "video"
          "work"
        ];
      }

      rec {
        host = "onus";
        server = "moth";
        # NOTE: this path corresponds to /volume1/shared/ on onus
        mountPath = "/home/${config.hostSpec.primaryUsername}/mount/${host}";
        folders = [
          "test"
        ];
      }
    ];
  };
}
