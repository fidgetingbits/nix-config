# NOTE: ollama uses a separate storage heirarchy (sha256) than llama-swap, so it's not
# possible (without scripting) to have them share a model folder. This means there can be
# huge duplication if running the same models in both (eg: deepseek-r1:70b is ~40gb)
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.llama;
  time = lib.custom.time;
  isImpermanent = config.system ? "impermanence" && config.system.impermanence.enable;
  modelsPath = "/var/lib/llm/models";
  cachePath = "/var/cache/llama-swap";
  user = config.users.users.${config.hostSpec.primaryUsername}.name;
  group = config.users.users.${config.hostSpec.primaryUsername}.group;
  persistFolder = config.hostSpec.persistFolder;
  # FIXME: Likely will want to manually re-compile this for our hardware
  # NOTE: AMD AI 395+ with rocm 6 and rocm 7.0.1 (see overlay) both crash loading gguf files
  #llama-cpp = pkgs.llama-cpp.override { rocmSupport = true; };
  llama-cpp = pkgs.llama-cpp.override { vulkanSupport = true; };
in
{
  options = {
    services.llama = {
      enable = lib.mkEnableOption "Run llama AI services";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.ollama = {
        enable = false;
        package = pkgs.unstable.ollama-rocm;
        host = "0.0.0.0";
        openFirewall = true;
        environmentVariables = {
          OLLAMA_KEEP_ALIVE = "1h";
          # Loading something like deepseek-r1:70b requires 40GB of RAM to
          # transfer to the GPU, but system only has 32GB
          GGML_CUDA_NO_PINNED = "1";
        };
      };

      systemd.tmpfiles.rules = [
        # Format: Type Path Mode UID GID Age Argument
        "d /var/lib/llm/models 0755 ${user} ${group} - -"
      ];

      environment.systemPackages = [
        llama-cpp # manual llama-server/llama-cli tests
        # FIXME: currently problen in 7.x PR: https://github.com/NixOS/nixpkgs/pull/469378
        # pkgs.rocmPackages.amdsmi
      ];

      # Good example of settings here:
      # yaml-based settings
      # https://github.com/basnijholt/dotfiles/blob/main/configs/nixos/hosts/pc/ai.nix
      # nix-based settings
      # https://github.com/skissue/dotfiles/blob/main/hosts/windstorm/llama-swap.nix
      services.llama-swap = {
        enable = true;
        openFirewall = true;
        port = config.hostSpec.networking.ports.tcp.llama-swap;

        settings =
          let
            llama-server = lib.getExe' llama-cpp "llama-server";
            ttl = 300; # How long the model stays in VRAM after last request
          in
          {
            # Timeout to download deepseek-r1:70b at ~50MB/s was ~15m, but I sometimes get
            # more like ~25MB/s depending on time of day, so double that to about ~60m
            # Pre-download larger models and use -m if you don't want massive stalls
            healthCheckTimeout = (time.minutes 60);
            macros = {
              # Systems using this atm are using AMD AI Max 395+ or AMD Ryzen AI 300
              # Justifications for flags:
              #   --jinja:    improve prompt correctness with marked-up prompt templates
              #   --fa:       VRAM is especially slow HBM, so flash attention is a win
              #   --no-webui: don't use it
              "server" = "${llama-server} --port \${PORT} -fa on --jinja --no-webui";
            };

            # NOTE: models cmds use the "server" macro defined above
            # -m is already downloaded model
            # -hf is direct download: <user>/<model>[:quant]
            models = {
              #-hf unsloth/DeepSeek-R1-Distill-Llama-70B-GGUF:Q6_K_XL
              "deepseek-r1:70b" = {
                inherit ttl;
                # --no-mmap : Model is larger than remaining system RAM
                cmd = ''
                  \''${server}
                  -m ${modelsPath}/DeepSeek-R1-Distill-Llama-70B-UD-Q6_K_XL-00001-of-00002.gguf
                  --ctx-size 32768
                  --no-mmap
                '';
                aliases = [
                  "ds-big"
                ];
              };
            };
          };
      };
      # When using -hf for models, it will auto-download from HuggingFace to this cache path
      systemd.services.llama-swap = {
        environment."LLAMA_CACHE" = cachePath;
        serviceConfig.CacheDirectory = "llama-swap";
      };
    })

    {
      environment = lib.optionalAttrs isImpermanent {
        persistence.${persistFolder}.directories = [
          "/var/lib/ollama"
          cachePath
          modelsPath
        ];
      };
    }
  ];
}
