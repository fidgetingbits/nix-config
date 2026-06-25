# NOTE: ollama uses a separate storage hierarchy (sha256) than llama-swap, so it's not
# possible (without scripting) to have them share a model folder. This means there can be
# huge duplication if running the same models in both (eg: deepseek-r1:70b is ~40gb)
{
  pkgs,
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.llama;
  time = lib.custom.time;
  modelsPath = "/var/lib/llm/models";
  cachePath = "/var/cache/private/llama-swap";

  pu = config.users.users.${config.hostSpec.primaryUsername};
  user = pu.name;
  group = pu.group;

  persistFolder = config.hostSpec.persistFolder;
  llama-settings =
    if config.hostSpec.useVulkan then { vulkanSupport = true; } else { rocmSupport = true; };
  llama-cpp = pkgs.llama-cpp.override llama-settings;
  ports = config.hostSpec.networking.ports;

  ttl = cfg.ttl;
  # Different hosts may only download/enable specific models, so let them select from this list
  # NOTE: models cmds use the "server" macro defined later in services.llama-swap.settings.macro
  #
  # -m is local gguf file
  # -hf is direct download: <user>/<model>[:quant]
  # --no-mmap : Model is larger than remaining system RAM
  models = {
    # Tested, but needs tweaks for strix halo
    "qwen3-vl:8b" = {
      inherit ttl;
      cmd = ''
        \''${server}
        -hf unsloth/Qwen3-VL-8B-Thinking-GGUF:Q8_K_XL
        --ctx-size 8192
        --temp 1.0
        --top-k 20
        --top-p 0.95
        --presence-penalty 0.0
      '';
    };

    # DEPRECATED
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
    # UNTESTED
    "qwen3-vl:8b-instruct" = {
      inherit ttl;
      cmd = ''
        \''${server}
        -hf unsloth/Qwen3-VL-8B-Instruct-GGUF:Q8_K_XL
        --ctx-size 8192
        --temp 0.7
        --top-k 20
        --top-p 0.8
        --presence-penalty 1.5
      '';
    };
    "qwen3:14b" = {
      inherit ttl;
      cmd = ''
        \''${server}
        -hf unsloth/Qwen3-14B-GGUF:UD-Q6_K_XL
        --ctx-size 8192
        --temp 0.6
        --top-k 20
        --top-p 0.95
        --min-p 0
        --presence-penalty 1.5'';
    };
    "qwen3:30b" = {
      inherit ttl;
      cmd = ''
        \''${server}
        -hf unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF:UD-IQ3_XXS
        --ctx-size 8192
        --temp 0.6
        --top-k 20
        --top-p 0.95
        --min-p 0
        --presence-penalty 1.0'';
    };
    "qwen3:30b-instruct" = {
      inherit ttl;
      cmd = ''
        \''${server}
        -hf unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF:UD-IQ3_XXS
        --ctx-size 8192
        --temp 0.7
        --top-k 20
        --top-p 0.8
        --min-p 0
        --presence-penalty 1.0'';
    };
    "qwen3-coder:30b" = {
      inherit ttl;
      cmd = ''
        \''${server}
        -hf unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-IQ3_XXS
        --ctx-size 8192
        --temp 0.7
        --top-k 20
        --top-p 0.8
        --presence-penalty 1.05'';
    };
  };
in
{
  options = {
    ${namespace}.services.llama = {
      enable = lib.mkEnableOption "Run llama AI services";
      ttl = lib.mkOption {
        type = lib.types.int;
        default = 0; # Persist
        description = "How long to wait before auto-unloading model from VRAM";
      };
      # FIXME: Add a check that the entries are inside cfg.hosts?
      # FIXME: Note for microvms you need to add them manually elsewhere for now
      allowedHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "foo" ];
        description = "List of host names that are allowed access to the llama service. Must have associated network entry";
      };
      hosts = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        # FIXME: Give an example of what this attrSet layout is or create a type
        default = config.hostSpec.networking.subnets.olan.hosts;
        description = "Attribute set of hosts used to lookup allowedHosts";
      };
      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "all" ];
        description = "Set of models you want to enable from the following (or \"all\" for everything): ${lib.attrNames models}";
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
        listenAddress = "0.0.0.0"; # We listen here even if granularFirewall is off because microvms may talk to it
        openFirewall = !config.networking.granularFirewall.enable;
        port = ports.tcp.llama-swap;

        settings =
          let
            llama-server = lib.getExe' llama-cpp "llama-server";
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

            models =
              if lib.elem "all" cfg.models then
                models
              else
                cfg.models
                |> map (model: models.model)
                # nixfmt hack
                |> lib.mergeAttrslist;
          };
      };

      # When using -hf for models, it will auto-download from HuggingFace to this cache path
      systemd.services.llama-swap = {
        environment = {
          "LLAMA_CACHE" = cachePath;
          "HF_HOME" = modelsPath;
        };
        serviceConfig.CacheDirectory = "llama-swap";

        # Prevent '[ERROR] failed to read sys stats: couldn't read /proc/meminfo:' spam
        serviceConfig = {
          # FIXME: Revisit this to figure out what is best for /proc/meminfo
          ProtectProc = lib.mkForce "default";
          ProcSubset = lib.mkForce "all";
        };
      };

      # If you don't specify an allowed host, it will be localhost only
      networking.granularFirewall = lib.optionalAttrs ((lib.length cfg.allowedHosts) != 0) (
        let
          hosts = lib.map (d: cfg.hosts.${d}) cfg.allowedHosts;
        in
        {
          enable = true;
          allowedRules = [
            {
              serviceName = "llama-swap";
              protocol = "tcp";
              ports = [ ports.tcp.llama-swap ];
              inherit hosts;
            }
          ];
        }
      );
    })

    (lib.mkIf cfg.enable {
      environment = lib.optionalAttrs config.introdus.impermanence.enable {
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
