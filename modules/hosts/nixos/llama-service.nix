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
  cachePath = "/var/cache/private/llama-swap";
  user = config.users.users.${config.hostSpec.primaryUsername}.name;
  group = config.users.users.${config.hostSpec.primaryUsername}.group;
  persistFolder = config.hostSpec.persistFolder;
  # NOTE: AMD AI 395+ with rocm 6 and rocm 7.0.1 (see overlay) both crash loading gguf files
  #llama-cpp = pkgs.llama-cpp.override { rocmSupport = true; };
  llama-cpp = pkgs.llama-cpp.override { vulkanSupport = true; };
in
{
  options = {
    services.llama = {
      enable = lib.mkEnableOption "Run llama AI services";
      ttl = lib.mkOption {
        type = lib.types.int;
        default = 0; # Persist
        description = "How long to wait before auto-unloading model from VRAM";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.ollama = {
        enable = false;
        # FIXME: This should be tied to if the system is using rocm or vulkan
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
            ttl = cfg.ttl;
          in
          {
            # Pre-download larger models and use -m if you don't want massive stalls
            # high health check timeout prevents it dying mid-download
            healthCheckTimeout = (time.minutes 60);
            macros = {
              # Systems using this atm are using AMD AI Max 395+ or AMD Ryzen AI 300
              #   --jinja:    improve prompt correctness with marked-up prompt templates
              #   --fa:       flash attention should speed up inference
              "server" = "${llama-server} --port \${PORT} -fa on --jinja --no-webui";
            };

            # NOTE: models cmds use the "server" macro defined above
            # -m is local gguf file
            # -hf is direct download: <user>/<model>[:quant]
            # --no-mmap : Model is larger than remaining system RAM
            models = {
              "deepseek-r1:30b" = {
                inherit ttl;
                cmd = ''
                  \''${server}
                  -m ${modelsPath}/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
                  --ctx-size 32768
                  --no-mmap
                '';
                aliases = [
                  "ds-big"
                  "agent"
                ];
              };
              "deepseek-r1:8b" = {
                inherit ttl;
                cmd = ''
                  \''${server}
                  -m ${modelsPath}/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf
                  --ctx-size 8192
                '';
                aliases = [
                  "ds-small"
                  "completion"
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

    (lib.mkIf cfg.enable {
      environment = lib.optionalAttrs isImpermanent {
        persistence.${persistFolder}.directories = [
          "/var/lib/ollama"
          modelsPath
          {
            # DynamicUser requires /var/cache/private
            directory = cachePath;
            user = "nobody";
            group = "nogroup";
          }
        ];
      };
    })
  ];
}
