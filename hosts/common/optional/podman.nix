{ config, lib, ... }:
{
  virtualisation = {

    podman = {
      enable = true;
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
      # Needed to use things like https://github.com/nektos/act to test github workflows
      dockerSocket.enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
    };
  };

  environment = lib.optionalAttrs config.system.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [ "/var/lib/containers" ];
    };
  };
}
