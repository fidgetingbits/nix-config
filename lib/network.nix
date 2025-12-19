{ lib, ... }:
{
  replaceLastOctet =
    ip: newOctet:
    let
      parts = lib.splitString "." ip;
      start = lib.take 3 parts;
      final = lib.concatStringsSep "." (start ++ [ newOctet ]);
    in
    final;
}
