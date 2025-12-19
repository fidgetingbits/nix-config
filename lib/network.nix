# FIXME: I suspect a lot of these could be cleaned up
{ lib, ports, ... }:
rec {
  replaceLastOctet =
    ip: newOctet:
    let
      addNewOctet = octets: octets ++ [ newOctet ];
    in
    ip
    |> lib.splitString "."
    |> lib.take 3
    |> addNewOctet
    # nixfmt hack
    |> lib.concatStringsSep ".";

  makeSubnet = ip: prefixLength: {
    wildcard = replaceLastOctet ip "*";
    prefixLength = prefixLength;
    ip = ip;
    cidr = "${ip}/${toString prefixLength}";
    gateway = replaceLastOctet ip "1";
    # The first three octets of the IP address
    triplet =
      lib.splitString "." ip
      |> lib.take 3
      # nixfmt hack
      |> lib.concatStringsSep ".";
  };

  makeHost = opts: {
    ${opts.name} = {
      inherit (opts)
        name
        ip
        ;
      mac = (if opts ? "mac" && builtins.isList opts.mac then opts.mac else [ opts.mac or "" ]);
      user = opts.user or "";
      sshPort = opts.sshPort or ports.tcp.ssh;
    };
  };

  # Return a set of host attrs
  makeSimpleHost =
    name: ip: mac: user:
    makeHost {
      inherit
        name
        ip
        user
        mac
        ;
    };

  incrementLastIPOctet =
    ip:
    let
      parts = lib.splitString "." ip;
      start = lib.take 3 parts;
      last = lib.toInt (lib.last parts);
      newLast =
        assert (
          lib.assertMsg (last < 255) "Last octet of ${ip} cannot be incremented because it is already 255)"
        );
        builtins.toString (last + 1);
      final = lib.concatStringsSep "." (start ++ [ newLast ]);
    in
    final;

  incrementLastMacOctet =
    mac:
    let
      parts = lib.splitString ":" mac;
      start = lib.take 5 parts;
      lastAsInt = lib.fromHexString (lib.last parts);
      newLastAsHex =
        assert (
          lib.assertMsg (
            lastAsInt < 255
          ) "Last octet of ${mac} cannot be incremented because it is already FF)"
        );
        lib.toHexString (lastAsInt + 1);
      # Integer 15 will be converted to "F" instead of "0F"
      # so we need to prepend values from integers < 16 with a "0"
      newLastFinal = if lastAsInt < 15 then "0${newLastAsHex}" else newLastAsHex;
      final = lib.concatStringsSep ":" (start ++ [ newLastFinal ]);
    in
    final;

  # Given the arguments: foo 0.0.0.0 00:00:00:00:00 bar
  # Return the sets:
  #     foo_vpn = { name="foo_vpn"; ip="0.0.0.0"; mac="00:00:00:00:00"; user="bar" };
  #     foo_adm = { name="foo_adm"; ip="0.0.0.1"; mac="00:00:00:00:01"; user="bar" };
  # This is because some network appliances will have two interfaces one for VPN and one
  # for admin connectivity, and need to access both
  makeADMandVPNHosts =
    name: ip: mac: user:
    let
      vpnIP = incrementLastIPOctet ip;
      vpnMac = incrementLastMacOctet mac;
    in
    lib.mergeAttrsList [
      (makeSimpleHost "${name}_adm" ip mac user)
      (makeSimpleHost "${name}_vpn" vpnIP vpnMac user)
    ];

}
