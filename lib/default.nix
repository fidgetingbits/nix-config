{ lib, ... }:
{
  # use path relative to the root of this project
  relativeToRoot = lib.path.append ../.;
}
