{ lib, ... }:
{
  imports = [
    (lib.custom.microvms.mkMicrovms ./.)
  ];
}
