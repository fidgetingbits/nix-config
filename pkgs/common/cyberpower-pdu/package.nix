{
  resholve,
  pkgs,
  lib,
  fetchgit,
  bash,
  net-snmp,
  coreutils,
  ...
}:
resholve.mkDerivation {
  pname = "cyberpower-pdu.sh";
  version = "d17a05aef9d0d0d86009775bf169091ac4a9f036";

  src = fetchgit {
    url = "https://github.com/fidgetingbits/cyberpower-pdu.sh.git";
    hash = "sha256-BFmV69XeqI8QLSq0dFKEZ/1ebJnDoK+sV/zBaisRW5U=";
  };
  nativeBuildInputs = [ pkgs.installShellFiles ];
  dontBuild = true;

  solutions = {
    default = {
      scripts = [ "bin/cyberpower-pdu" ];
      interpreter = "${bash}/bin/bash";
      inputs = [
        coreutils
        net-snmp
      ];
    };
  };
  installPhase = ''
    install -m 755 -D cyberpower-pdu --target-directory $out/bin
  '';
  postInstall = ''
    installManPage cyberpower-pdu.1.gz
    installShellCompletion --bash completions/bash/cyberpower-pdu \
      --zsh completions/zsh/_cyberpower-pdu \
      --fish completions/fish/cyberpower-pdu.fish
  '';
  meta = {
    homepage = "https://github.com/fidgetingbits/cyberpower-pdu.sh";
    license = lib.licenses.gpl3;
    longDescription = ''

    '';
    maintainers = [ lib.maintainers.fidgetingbits ];
  };
}
