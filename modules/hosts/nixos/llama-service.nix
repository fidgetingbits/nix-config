# WARNING: This is tweaked for two AMD AI chipsets atm, so won't work on other systems
# FIXME: This needs to get broken out into multiple files now I think
{
  pkgs,
  lib,
  config,
  namespace,
  ...
}:
let

  isHalo = config.networking.hostName == "oedo";
  cfg = config.${namespace}.services.llama;
  time = lib.custom.time;
  modelsPath = "/var/lib/llm/models";
  cachePath = "/var/cache/private/llama-swap";

  pu = config.users.users.${config.hostSpec.primaryUsername};
  user = pu.name;
  group = pu.group;

  persistFolder = config.hostSpec.persistFolder;
  # Some notes taken from
  # https://github.com/basnijholt/dotfiles/blob/6f8a47c1/configs/nixos/hosts/pc/package-overrides.nix
  # https://github.com/blazed/cake/blob/ee606cf/profiles/ai.nix
  llama-cpp =
    (pkgs.llama-cpp.override {
      rocmSupport = !config.hostSpec.useVulkan;
      vulkanSupport = config.hostSpec.useVulkan;
      # Enable BLAS for optimized CPU layer performance (OpenBLAS)
      # This is crucial for models using split-mode or CPU offloading
      blasSupport = true;
      cudaSupport = false;
      rocmGpuTargets = if isHalo then [ "gfx1151" ] else [ "gfx1150" ];
    }).overrideAttrs
      (oldAttrs: rec {
        version = "9775";
        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b${version}";
          hash = "sha256-kTY9Pwzk8JbmlTwfCpKMenK2PB9lob69sbq8R55wCsw=";
          leaveDotGit = true;
          postFetch = ''
            git -C "$out" rev-parse --short HEAD > $out/COMMIT
            find "$out" -name .git -print0 | xargs -0 rm -rf
          '';
        };
        npmRoot = "tools/ui";
        npmDepsHash = "sha256-0dctM/apI3ysMIEVBaBXO9hZMWskpJpNpOws1gwiOYc=";

        cmakeFlags =
          (oldAttrs.cmakeFlags or [ ])
          ++ [
            "-DGGML_NATIVE=ON"
            "-DGGML_HIP_NO_VMM=ON"
            "-DCMAKE_HIP_FLAGS=-I${pkgs.rocmPackages.rocwmma}/include"
          ]
          ++ lib.optionals (!isHalo) [
            # This is buggy on 1151 apparently, so disabled for now
            # https://github.com/ggml-org/llama.cpp/issues/24437
            "-DGGML_HIP_ROCWMMA_FATTN=ON"
          ];

        # Disable Nix's NIX_ENFORCE_NO_NATIVE which strips -march=native flags
        # See: https://github.com/NixOS/nixpkgs/issues/357736
        # See: https://github.com/NixOS/nixpkgs/pull/377484 (intentionally contradicts this)
        preConfigure = ''
          export NIX_ENFORCE_NO_NATIVE=0
          ${oldAttrs.preConfigure or ""}
        '';
      });

  ports = config.hostSpec.networking.ports;

  qwenSampling = [
    "--temp 0.6"
    "--top-p 0.95"
    "--top-k 20"
    "--min-p 0.00"
  ];
  gemmaSampling = [
    "--temp 1.0"
    "--top-p 0.95"
    "--top-k 64"
    "--min-p 0.01"
  ];

  llama-server = lib.getExe' llama-cpp "llama-server";

  # KV dtype convention: q8 weights keep q8_0/q8_0 (max-context memory saving);
  # q4/q6 weights use f16/f16 (f16 avoids the severe long-context slowdown that
  # quantized V cache causes on gfx1151).
  mkModel =
    {
      hf,
      kv,
      ctx ? 262144,
      sampling ? qwenSampling,
      mtp ? false,
      thinking ? true,
      name ? "",
    }:
    {
      meta = {
        inherit name;
      };
      # -m is local gguf file
      # -hf is direct download: <user>/<model>[:quant]
      # --no-mmap : Model might be larger than remaining system RAM
      cmd = lib.concatStringsSep "\n" (
        [
          llama-server
          # FIXME: Should tweak this for optional local models?
          "-hf ${hf}"
          "--port \${PORT}"
          "--ctx-size ${toString ctx}"
          "--batch-size 4096"
          "--ubatch-size 2048"
          "--cache-reuse 256"
          # FIXME: Could make this configurable
          # "--threads 16"
          # "--threads-batch 32"
          "--kv-unified"
          "-ngl 999"
          "-fa on"
          "--cache-type-k ${kv}"
          "--cache-type-v ${kv}"
          "--no-mmap"
          "--direct-io"
        ]
        ++ sampling
        ++ [
          "--repeat-penalty 1.0"
          "--jinja"
          "--metrics"
          "--slots"
        ]
        ++ lib.optionals mtp [
          "--spec-type draft-mtp"
          "--spec-draft-n-max 2"
        ]
        ++ lib.optionals thinking [
          "--chat-template-kwargs '{\"preserve_thinking\":true}'"
        ]
      );
    };

  # Strix Halo box has more available ram for f16 kv cache,
  # but stick to q8 on Strix Point
  # NOTE: realistically don't run the ones that want f16 on ossa anyway,
  # but have it for benchmark testing
  genQ4KV = if isHalo then "f16" else "q8_0";
  models = {
    "qwen3.6:27b-mtp-q8" = mkModel {
      name = "Qwen 3.6 27B MTP (8-bit High Precision)";
      hf = "unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q8_K_XL";
      kv = "q8_0";
      mtp = true;
    };
    "qwen3.6:27b-mtp-q4" = mkModel {
      name = "Qwen 3.6 27B MTP (4-bit Performance/Max Context)";
      hf = "unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL";
      kv = genQ4KV;
      mtp = true;
    };
    "qwen3.6:35b-a3b-mtp-q4" = mkModel {
      name = "Qwen 3.6 35B A3B MTP (4-bit Performance / Active Blocks)";
      hf = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL";
      kv = genQ4KV;
      mtp = true;
    };
    "qwen3.6:35b-a3b-mtp-q8" = mkModel {
      name = "Qwen 3.6 35B A3B MTP (8-bit High Precision / Active Blocks)";
      hf = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q8_K_XL";
      kv = "q8_0";
      mtp = true;
    };
    "qwen3.6:27b-q8" = mkModel {
      name = "Qwen 3.6 27B Standard (8-bit High Precision)";
      hf = "unsloth/Qwen3.6-27B-GGUF:UD-Q8_K_XL";
      kv = "q8_0";
    };
    "qwen3.6:27b-q4" = mkModel {
      name = "Qwen 3.6 27B Standard (4-bit Performance/Max Context)";
      hf = "unsloth/Qwen3.6-27B-GGUF:UD-Q4_K_XL";
      kv = genQ4KV;
    };
    "qwen3.6:35b-a3b-q4" = mkModel {
      name = "Qwen 3.6 35B A3B Standard (4-bit Performance / Active Blocks)";
      hf = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
      kv = genQ4KV;
    };
    "qwen3.6:35b-a3b-q8" = mkModel {
      name = "Qwen 3.6 35B A3B Standard (8-bit High Precision / Active Blocks)";
      hf = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q8_K_XL";
      kv = "q8_0";
    };
    "gemma-4:31b-q6" = mkModel {
      name = "Gemma 4 31B Instruct (6-bit Balanced / High Context)";
      hf = "unsloth/gemma-4-31B-it-GGUF:UD-Q6_K_XL";
      kv = "f16";
      ctx = 200000;
      sampling = gemmaSampling;
      thinking = false;
    };
    "gemma-4:26b-a4b-q6" = mkModel {
      name = "Gemma 4 26B A4B Instruct (6-bit Balanced / Active Blocks)";
      hf = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q6_K_XL";
      kv = "f16";
      ctx = 200000;
      sampling = gemmaSampling;
      thinking = false;
    };

    # Fill-in-the-middle (FIM) aka Next Edit Suggestion (NES)
    "qwen2.5-coder:1.5b-fim" = mkModel {
      name = "Qwen 2.5 Coder 1.5B (Low Latency FIM)";
      hf = "unsloth/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0";
      ctx = 4096;
      kv = "f16";
      # Inline completion must be highly deterministic to prevent syntax breakage
      sampling = [
        "--temp 0.0" # Greedy decoding: always pick the highest-probability token
        "--top-k 1" # Locks selection to the single absolute best match
        "--min-p 0.0" # Disable dynamic cutoffs; temp 0 handles it
        "--repeat-penalty 1.0" # Disabled: prevents breaking repetitive code blocks like brackets
        "--presence-penalty 0.0" # Disabled: allows necessary variable/syntax repetition
      ];
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

        settings = {
          # Pre-download larger models and use -m if you don't want massive stalls
          # high health check timeout prevents it dying mid-download
          healthCheckTimeout = (time.minutes 60);
          globalTTL = cfg.ttl;

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

        # Some settings from https://github.com/blazed/cake/blob/ee606c/profiles/ai.nix#L256
        serviceConfig = {
          LimitMEMLOCK = "infinity";
          CacheDirectory = "llama-swap";
          # The upstream module sets ProcSubset = "pid", which hides /proc/meminfo, /proc/stat
          # and /proc/loadavg - the performance monitor's gopsutil reads need them. Relax it so
          # system CPU/RAM/load metrics work (other processes stay hidden via ProtectProc).
          # Fixes '[ERROR] failed to read sys stats: couldn't read /proc/meminfo:' spam
          ProcSubset = lib.mkForce "all";
          Environment = [
            # rocm-smi (GPU backend for the performance monitor) is appended to PATH.
            "PATH=/run/current-system/sw/bin:${pkgs.rocmPackages.rocm-smi}/bin"
            "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
            "XDG_CACHE_HOME=/var/cache"
            # Use hipBLASLt GEMMs when loadable (rocBLAS falls back silently otherwise).
            # FIXME: Investigate this
            "ROCBLAS_USE_HIPBLASLT=1"
          ]
          ++
            # Framework 16 1150
            lib.optionals (config.networking.hostName == "ossa") [
              # Avoid the buggy System Direct Memory Access (SDMA) copy path on unified memory.
              "HSA_ENABLE_SDMA=0"
              # Let ROCm allocate from the full unified-memory/GTT pool on this APU.
              "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1"
              # Strix Point (gfx1150) ROCm tuning:
              "HSA_OVERRIDE_GFX_VERSION=11.5.0"
            ]
          ++
            # Beelink GR9
            # NOTE: We have 96gb dedicated to GPU in bios, so no UMA
            lib.optionals (config.networking.hostName == "oedo") [
              # Strix Halo (gfx1151) ROCm tuning:
              "HSA_OVERRIDE_GFX_VERSION=11.5.1"
            ];
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
