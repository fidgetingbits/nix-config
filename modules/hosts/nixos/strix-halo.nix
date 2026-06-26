# This allows you to specify ttm kernel settings, which dictate how much
# VRAM can be dynamically used by the gpu at runtime. It is only applicable
# if your system doesn't have some dedicated UMA block assigned for the GPU
{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.strix-halo;
in
{
  options.${namespace}.strix-halo = {
    enable = lib.mkEnableOption "Enable strix halo options";
    sharedMemory = lib.mkOption {
      type = lib.types.int;
      description = "Size of memory (in GB) to make allocatable for GTT";
    };
  };
  config = lib.mkIf cfg.enable {
    # See:
    #  https://www.jeffgeerling.com/blog/2025/increasing-vram-allocation-on-amd-ai-apus-under-linux/
    #  https://github.com/ROCm/ROCm/issues/5562#issuecomment-3452179504
    #  https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/native_linux/install-ryzen.html#configure-shared-memory
    #  https://blog.linux-ng.de/2025/07/13/getting-information-about-amd-apus/
    #
    # You can allegedly use newer amd-smi options to manually set this as well:
    # https://github.com/ROCm/rocm-systems/pull/3636
    boot.kernelParams =
      let
        sz = toString ((cfg.sharedMemory * 1024 * 1024 * 1024) / 4096);
      in
      [
        "amd_iommu=off" # disables VFIO for local llm speed
        "amdttm.pages_limit=${sz}"
        "amdttm.page_pool_size=${sz}"
        "ttm.pages_limit=${sz}"
        "ttm.page_pool_size=${sz}"
      ];
  };
}
