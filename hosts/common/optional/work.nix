{ secrets, lib, ... }:
{
  security.pki.certificateFiles = lib.attrValues secrets.work.certs;
}
