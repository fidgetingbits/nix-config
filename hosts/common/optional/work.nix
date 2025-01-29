{ inputs, lib, ... }:
{
  security.pki.certificateFiles = lib.attrValues inputs.nix-secrets.work.certs;
}
