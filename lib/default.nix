{ lib, ... }:
rec {
  # sub libs
  time = import ./time.nix;
  network = import ./network.nix { inherit lib; };

  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;

  # Imports any .nix file in the specific directory, and any folder that
  # contains a default.nix. Note this means that a folder containing
  # `default.nix` and other *.nix files is expected to use the other *.nix
  # files in that folder as supplementary, and not distinct modules
  scanPaths =
    path:
    lib.map (f: (path + "/${f}")) (
      builtins.readDir path
      |> lib.attrsets.filterAttrs (
        file: _type:
        (_type == "directory" && lib.pathExists (path + "/${file}/default.nix"))
        || (file != "default.nix" && lib.strings.hasSuffix ".nix" file)
      )
      |> lib.attrNames
    );

  leaf = str: lib.last (lib.splitString "/" str);
  scanPathsFilterPlatform =
    path:
    lib.filter (
      path: lib.match "nixos.nix|darwin.nix|nixos|darwin" (leaf (builtins.toString path)) == null
    ) (scanPaths path);
}
