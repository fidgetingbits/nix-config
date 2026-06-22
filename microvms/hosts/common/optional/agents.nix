{ lib, vmOpts, ... }:
{
  home-manager = {
    users.${vmOpts.user} = {
      imports = (
        map lib.custom.relativeToRoot [
          "microvms/home/common/optional/agent.nix"
        ]
      );
    };
  };
}
