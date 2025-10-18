{ lib, ... }:
rec {
  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;

  scanPaths =
    path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
          (_type == "directory") # include directories
          || (
            (path != "default.nix") # ignore default.nix
            && (lib.strings.hasSuffix ".nix" path) # include .nix files
          )
        ) (builtins.readDir path)
      )
    );

  leaf = str: lib.last (lib.splitString "/" str);
  scanPathsFilterPlatform =
    path:
    lib.filter (
      path: builtins.match "nixos.nix|darwin.nix|nixos|darwin" (leaf (builtins.toString path)) == null
    ) (scanPaths path);
}
