# Installing nix-config on a new system

Bootstrapping a system uses a "minimal" configuration for most hosts, which is
significantly stripped down in order to speed up testing to make sure the bare
minimum works. This _normally_ is good, but sometimes leads to some bumps.

Bootstrapping is done by the `nixos-bootstrap` tool that is part of the
introdus config. It is run on the *source* host to install NixOS onto the
*target* host.

Although much of the process is automated, there are still some manual steps.

## Requirements for installing a new host

### Pre-installation steps:

1. Add `nix-config/hosts/nixos/[hostname]/` and `nix-config/home/[user]/[hostname].nix` files. You must declare the configuration settings for the target host as usual in your nix-config.
   Be sure to specify the device name (e.g. sda, nvme0n1, vda, etc) you want to install to along with the desired `nix-config/hosts/common/disks` disko spec.

   If needed, you can find the device name on the target machine itself by booting it into the iso environment and running `lsblk` to see a list of the devices. Virtual Machines often using a device called `vda`.
2. Add a `newConfig` entry for the target host in `nix-config/nixos-installer/flake.nix`, passing in the required arguments as noted in the file comments.
3. If you are planning to use the `backup` module on the target host, you _must_ temporarily disable it in the target host's config options until bootstrapping is complete. Failure to disable these two modules, will cause nix-config to look for the associated secrets in the new `[hostname].yaml` secrets file where they have not yet been added, causing sops-nix to fail to start during the build process. After rebuilding, we'll add the required keys to secrets and re-enable these modules.
    For example:
    ```nix
    # nix-config/hosts/nixos/guppy/default.nix
    #--------------------

    # ...
       # The back module is enabled via a services option. Set it to false.
        services.backup = {
            enable = false;
            # ...
        };
       #...
    ```

## New host setup

- Add `hosts/nixos/<hostname>/{default, disks, host-spec}.nix`
- Find disk name from livecd with `lsblk`
- Find RAM amount form livcd with `free -m`
  - Only relevant if using swap
- If using backup, add a borg passphrase to nix-secrets or temporarly disable
  backup from the config

## Deployment steps

- Run `just up <hostname>` to generate a lock file
- If you need a new liveusb::
  - run `just iso` to generate an iso file
  - Use the generated `result/iso/*.iso` file to boot into it on the target
    machine/vm
  - Run `just iso-install <disk>` to generate the iso file automatically copy
    it onto a USB drive

### 0. VM setup (optional)

This is only relevant if you are not using a physical system.

- If you are using swap, remember a lot of space will be used for swap from your main disk (maybe 16GB) so setup a 40GB
  if you want a 20GB disk, or pass `withSwap = false;` to the disko module in `nixos-installer/flake.nix`
- Setup UEFI
- Add the DVD-rom pointing to the iso
- Add the yubikey device (FIXME: Elaborate what this means for the VM)
- Record the ip address after initial boot

### 1. Run the bootstrap script

Boot your target and be sure to change the boot order so DVD-ROM is second and the installation disk is first. This is because nixos-anywhere will reboot this system and expect it to boot into the new system.

This is an example of running it from `nix-config` base folder installing on a VM (`okra`):

```bash
scripts/bootstrap-nixos.sh -n=okra -d=192.168.122.29 -k=~/.ssh/id_yubikey -u=aa --impermanence
```
Answer the questions.

### 2. Post install steps for LUKS (optional)

#### Change LUKS2's passphrase if you entered a temporary passphrase during bootstrap

```bash
# when entering /path/to/dev/ you must specify the partition (e.g. /dev/nvmeon1p2)
# test the old passphrase
sudo cryptsetup --verbose open --test-passphrase /path/to/dev/

# change the passphrase
sudo cryptsetup luksChangeKey /path/to/dev/

# test the new passphrase
sudo cryptsetup --verbose open --test-passphrase /path/to/dev/
```

#### Update the unlock passphrase for secondary drive unlock

If you passed the `--luks-secondary-drive-labels` arg when running the bootstrap script, it automatically created a `/luks-secondary-unlock.key` file for you using the passphrase you specified during bootstrap.
If you used a temporary passphrase during bootstrap, you can update the secondary unlock key by running the following command and following the prompts.

```bash
cryptsetup luksChangeKey /luks-secondary-unlock.key
```

#### Manual secondary drive setup

This is only relevant if for some reason you didn't setup the secondary disks
with the bootstrap script.

From - https://wiki.nixos.org/wiki/Full_Disk_Encryption#Unlocking_secondary_drives :

1. Create a keyfile for your secondary drive(s), store it safely and add it as a LUKS key:

```bash
# dd bs=512 count=4 if=/dev/random of=/luks-secondary-unlock.key iflag=fullblock
# chmod 400 /luks-secondary-unlock.key
```

You can specify your own name for `luks-secondary-unlock.key`
2. For each secondary device, run the following command and specify the respective device:

```bash
# cryptsetup luksAddKey /path/to/dev /luks-secondary-unlock.key
```

3. Create /etc/crypttab in configuration.nix using the following option (replacing UUID-OF-SDB with the actual UUID of /dev/sdb):

To list the UUIDs of the devices use: `sudo lsblk -o +name,mountpoint,uuid`
You need the UUID of the partition that the volume exists on, not the uuid of the volume itself

```nix
{
   environment.etc.crypttab.text = ''
    volumename UUID=UUID-OF-SDB /mykeyfile.key
  ''
}
```
example:
```nix
{
   environment.etc.crypttab.text = ''
    cryptextra UUID=569e2951-1957-4387-8b51-f445741b02b6 /luks-secondary-unlock.key
  ''
}
```

With this approach, the secondary drive is unlocked just before the boot process completes, without the need to enter its password.
The secondary drive will be unlocked and made available under /dev/mapper/cryptstorage for mounting.


#### Enroll yubikeys for touch-based LUKS unlock

Enable yubikey support:

NOTE: This requires LUKS2 (use cryptsetup luksDump /path/to/dev/ to check)

```bash
sudo systemd-cryptenroll --fido2-device=auto /path/to/dev/
```

You will need to do it for each yubikey you want to use.

### 4. Deploying the target flake's main NixOS configuration

To trigger a full build on the new host run.

```bash
just build-host <host>
```

If you plan to do the build's locally on the host, then you can ssh in and go to the `nix-config` folder and run:

```bash
just rebuild


```

## 5. Everything else

Here you should have a fully working system, but some stuff you still need to do:

- login to proton
- Add new u2f_keys to nix-secrets if you plan to use yubikey locally on the device
  - Run `pamu2fcfg` for each yubikey token you want to add. Append additional yubikeys to the first line using `:` and
    removing the username. Also note if using zsh the final `%` is not to be included. Place these into your sops file under a heading like:

    ```yaml
      keys:
        u2f: xxx
    ```
- If on local network and will be using email, add a postfix relay password to the new systems `host.yaml` if using backups. Use `just dovecot-hash` to generate the
  entry for `ooze.yaml` sops file. You will have to rebuild `ooze`.
- If not on local network, and will be using email, setup msmtp creds only.

- Recover any backup files needed
  - .mozilla
  - syncthing
- Log into firefox
- Re-link signal
- Setup atuin
  - `atuin login`
  - Use existing `aa` user login to get key
  - Use `atuin key` output from any other box already logged in?
    - FIXME: Not sure if this is right, because some hosts have different keys
  - Add `.local/share/autin/key` to  `keys/atuin` in sops secrets
- Manually set syncthing username/password
- login to spotify
- podman login
- Setup talon
  - Run bootstrap scripts (if not handled by backup recovery)
  - Rebuild cursorless/command-server extensions

## Troubleshooting

### Rebooting a VM into the minimal-config environment hangs indefinitely on "booting in to hard disk..."

There are two know causes for this issue:

1. The VM __must__ be created with the hypervisor firmware set to UEFI instead of BIOS. You will likely have to re-create the VM as this can't be changed after the fact.

2. The `hardware-configuration.nix` file may not have the required virtual I/O kernel module. Depending on the VM device type you will need to add either `virtio_pci` or `virtio_scsi` to the list of `availableKernelModules` in the host's `hardware-configuration.nix`
   For example:
   ```nix
   # nix-config/hosts/nixos/guppy/hardware-configuration.nix
   # -------------------

    # ...
       boot.initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "virtio_pci"
      "sr_mod"
      "virtio_blk"
    ];
    # ...

## Generating a custom NixOS ISO

We recommend using a custom ISO similar to what is defined in `nix-config/hosts/nixos/iso`. The official minimal NixOS iso has historical omitted some basic tty utilities that are expected by the installer scripts. The config for the ISO used in nix-config are similarly light-weight to [`nixos-installer/flake.nix`](flake.nix).

To generate the ISO, simply run `just iso` from the root of your `nix-config` directory. The resulting .iso file will be saved to `nix-config/result/iso/foo.iso`. A symlink to the file is also created at `nix-config/latest.iso`. The filename is time stamped for convenient reference when frequently trying out different ISOs in VMs. For example, `nixos-24.11.20250123.035f8c0-x86_64-linux.iso`.

If you are installing the host to a VM or remote infrastructure, configure the machine to boot into the .iso file.

If you are installing on a bare metal machine, write the .iso to a USB device. You can generate the iso and write it to a device in one command, using `just iso /path/to/usb/device`.
