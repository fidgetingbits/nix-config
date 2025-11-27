# FIXME(network): Revisit this now that oedo has changed
{ ... }:
{

  # FIXME(network): Ideally this should be done using the networking.interfaces approach, but doesn't seem to work...
  # In the interfaces change due to me using usb dongles, we should explicitly test if they interface being used is
  # assign to an IP address that we expect to be the one we want their route for
  # FIXME: re-enable eventually
  # networking.dhcpcd.wait = "background";
  #  networking.dhcpcd.runHook =
  #    let
  #      network = inputs.nix-secrets.networking;
  #    in
  #    ''
  #      if [ "$reason" = "BOUND" ]; then
  #        if [ "$new_ip_address" = "${network.subnets.ogre.hosts.oedo.ip}" ]; then
  #          ${lib.getBin pkgs.iproute2}/bin/ip route add \
  #            ${network.subnets.lab.cidr} \
  #            via ${network.subnets.ogre.hosts.ottr.ip} \
  #            dev $interface \
  #            2>>/tmp/error
  #        fi
  #        # ${lib.getBin pkgs.iproute2}/bin/ip route add \
  #        #   ${network.subnets.lab.cidr} \
  #        #   via ${network.subnets.ogre.hosts.ottr.ip} \
  #        #   dev enp0s20f0u1u4 \
  #        #   2>>/tmp/error
  #    '';

  # not working...
  # Setup custom routes for the lab
  #  networking.interfaces =
  #    let
  #      interfaceNames = [
  #        "enp0s13f0u1u1"
  #        "wlp0s20f3"
  #      ];
  #      labRoute = {
  #        address = inputs.nix-secrets.networking.subnets.lab.ip;
  #        prefixLength = inputs.nix-secrets.networking.subnets.lab.prefixLength;
  #        via = inputs.nix-secrets.networking.subnets.ogre.hosts.ottr.ip;
  #      };
  #      interfaceRoutes = lib.attrsets.mergeAttrsList (
  #        lib.map (name: { ${name}.ipv4.routes = [ labRoute ]; }) interfaceNames
  #      );
  #    in
  #    lib.trace lib.trace interfaceRoutes;

  # FIXME: Double check these after
  #  networking.interfaces.enp196s0f0.ipv4.routes = [
  #    {
  #      address = inputs.nix-secrets.networking.subnets.lab.ip;
  #      prefixLength = inputs.nix-secrets.networking.subnets.lab.prefixLength;
  #      via = inputs.nix-secrets.networking.subnets.ogre.hosts.ottr.ip;
  #    }
  #  ];
  #
  #  networking.interfaces.wlp193s0.ipv4.routes = [
  #    {
  #      address = inputs.nix-secrets.networking.subnets.lab.ip;
  #      prefixLength = inputs.nix-secrets.networking.subnets.lab.prefixLength;
  #      via = inputs.nix-secrets.networking.subnets.ogre.hosts.ottr.ip;
  #    }
  #  ];

  # WARNING: This prevented your internet from working...
  #systemd.network = {
  #  enable = true;
  #  links."10-eth0" = {
  #    linkConfig.Name = "eth0";
  #    matchConfig.MACAddress = config.hostSpec.networking.foo;
  #  };
  #  links."11-wlan0" = {
  #    linkConfig.Name = "wlan0";
  #    matchConfig.MACAddress = config.hostSpec.networking.bar;
  #  };
  #};
  #systemd.network.wait-online.ignoredInterfaces = [ "wlan0" ];
  #systemd.services.NetworkManager-wait-online.enable = false;
  #systemd.services.systemd-networkd-wait-online.enable = false;
}
