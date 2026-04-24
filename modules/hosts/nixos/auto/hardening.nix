# Currently just mirroring suggestions from the wiki for now
# https://wiki.nixos.org/wiki/NixOS_Hardening
# Also poking at some stuff mentioned here:
# https://github.com/NarrativeScience-old/nixpkgs/blob/cc6cf0a96a627e678ffc996a8f9d1416200d6c81/nixos/modules/profiles/hardened.nix#L25
# Use https://github.com/a13xp0p0v/kernel-hardening-checker/ as guideline for more options
{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.hostSpec.isDesktop && config.hostSpec.hostName == "ossa") {

    # Makes userland exploitation of memory-corruption bugs more difficult
    # FIXME: Disable until firefox/chromium/etc is wrapped
    # environment.memoryAllocator.provider = "graphene-hardened";

    # Makes slab and buddy allocator exploitation more difficult.
    boot.kernelParams = [
      # Slab/slub sanity checks, redzoning, and poisoning
      "slub_debug=FZP"

      # Disable slab merging to make certain heap overflow attacks harder
      "slab_nomerge"

      # Overwrite free'd memory
      "page_poison=1"

      # Disable legacy virtual syscalls
      "vsyscall=none"

      # Enable page allocator randomization
      "page_alloc.shuffle=1"

      # Don't leak kernel addresses in logs
      "hash_pointers=always"
    ];

    # Preventing the loading of modules helps prevents exposure to privilege
    # escalation via kernel bugs, as well as (in theory) reducing the
    # availability of certain exploit primitives
    boot.blacklistedKernelModules = [
      # Obscure network protocols
      "ax25"
      "netrom"
      "rose"

      # Old or rare or insufficiently audited filesystems
      "adfs"
      "affs"
      "bfs"
      "befs"
      "cramfs"
      "efs"
      "erofs"
      "exofs"
      "freevxfs"
      "f2fs"
      "hfs"
      "hpfs"
      "jfs"
      "minix"
      "nilfs2"
      "qnx4"
      "qnx6"
      "sysv"
      "ufs"
    ];

    # Allowing users to mmap() memory starting at virtual address 0 can turn a
    # NULL dereference bug in the kernel into code execution with elevated
    # privilege.  Mitigate by enforcing a minimum base addr beyond the NULL memory
    # space.  This breaks applications that require mapping the 0 page, such as
    # dosemu or running 16bit applications under wine.  It also breaks older
    # versions of qemu.
    #
    # The value is taken from the KSPP recommendations (Debian uses 4096).
    boot.kernel.sysctl."vm.mmap_min_addr" = lib.mkDefault 65536;
    boot.kernel.sysctl."kernel.kptr_restrict" = lib.mkOverride 500 2;

    # Limit which users can use nix.
    # This reduces exposure to privilege escalation bugs like CVE-2026-39860
    nix.settings.allowed-users = [ "@users" ];
  };
}
