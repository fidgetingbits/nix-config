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
  cfg = config.${namespace}.services.llama-swap;
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

  # Check unsloth "Best Practices" section to find these
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
      embedding ? false,
      alias ? "",
    }:
    {
      aliases = lib.optional ((lib.stringLength alias) != 0) alias;
      # -m is local gguf file
      # -hf is direct download: <user>/<model>[:quant]
      # --no-mmap : Model might be larger than remaining system RAM
      cmd = lib.concatStringsSep "\n" (
        [
          llama-server
          # FIXME: Should tweak this for optional pre-downloaded models with -m
          "-hf ${hf}"
          "--port \${PORT}"
          "--ctx-size ${toString ctx}"
          "--batch-size 4096"
          "--ubatch-size 2048"
          "--cache-reuse 256"
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
        ++ lib.optionals embedding [
          "--embedding"
        ]
      );
    };

  # Strix Halo box has more available ram for f16 kv cache,
  # but stick to q8 on Strix Point. Need to test how much
  # this actually matters in practice
  genKV = if isHalo then "f16" else "q8_0";
  # IMPORTANT: These names are mirrored in neovim for minuet/codecompanion. If
  # you change the naming scheme update. See lua/llms.lua
  models = {
    ##
    # QWEN
    ##

    # strix halo: pp 71.79 t/s, tg 58.24 t/s
    # strix point: pp 36.59 t/s, tg 20.18 t/s
    "Qwen 3.6 Coder 30B (Light)" = mkModel {
      hf = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q6_K_XL";
      kv = "f16";
      sampling = [
        "--temp 0.7"
        "--top_p 0.95"
        "--top_k 20 "
      ];
      thinking = false;
      alias = "qwen3.6:coder-30b-a3b-q6";
    };

    # strix halo: pp 73.48 t/s, tg 68.41 t/s
    # strix point: pp 41.37 t/s, tg 18.67 t/s
    "Qwen 3.6 General 35B Q4 (Light)" = mkModel {
      hf = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL";
      kv = genKV;
      mtp = true;
      alias = "qwen3.6:35b-a3b-mtp-q4";
    };

    # strix halo: pp 71.48 t/s, tg 59.11 t/s
    # strix point:
    "Qwen 3.6 General 35B Q8 (Light)" = mkModel {
      hf = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q8_K_XL";
      kv = "q8_0";
      mtp = true;
      alias = "qwen3.6:35b-a3b-mtp-q8";
    };

    # strix halo: pp 40.73 t/s, tg 19.73 t/s
    # strix point:
    "Qwen 3.6 General 27B (Heavy)" = mkModel {
      hf = "unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL";
      kv = genKV;
      mtp = true;
      alias = "qwen3.6:27b-mtp-q4";
    };

    # strix halo: pp 695.34 t/s, tg 106.98 t/s
    # strix point: pp 379.23 t/s, tg 36.51 t/s
    "Qwen 2.5 Coder 1.5B (Ultra Light)" = mkModel {
      hf = "unsloth/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0";
      ctx = 4096;
      kv = "f16";
      sampling = qwenSampling;
      alias = "qwen2.5:coder-1.5b-q8";
    };

    ##
    # GEMMA
    ##

    # strix halo: pp 96.89 t/s, tg 42.02 t/s
    # strix point: pp 43.88 t/s, tg 14.73 t/s
    "Gemma 4 26B (Light)" = mkModel {
      hf = "unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q6_K_XL";
      kv = "f16";
      ctx = 200000;
      sampling = gemmaSampling;
      thinking = false;
      alias = "gemma-4:26b-a4b-q6";
    };

    # strix halo: pp 57.31 t/s, tg 7.41 t/s
    "Gemma 4 31B (Super Heavy)" = mkModel {
      hf = "unsloth/gemma-4-31B-it-GGUF:UD-Q6_K_XL";
      kv = "f16";
      ctx = 200000;
      sampling = gemmaSampling;
      thinking = false;
      alias = "gemma-4:31b-q6";
    };

    "Nomic Embeddings" = mkModel {
      hf = "nomic-ai/nomic-embed-text-v1.5-GGUF:F16";
      kv = "f16";
      ctx = 8192; # Nomic v1.5's native max context window
      sampling = [ ];
      thinking = false;
      embedding = true;
      alias = "nomic-embed-text";
    };
  };
in
{
  options = {
    ${namespace}.services.llama-swap = {
      enable = lib.mkEnableOption "Enable llama-swap";
      ttl = lib.mkOption {
        type = lib.types.int;
        default = 0; # Persist
        description = "How long to wait before auto-unloading model from VRAM";
      };

      # FIXME: Add a check that the entries are inside cfg.hosts?
      # FIXME: Note for microvms you need to add them manually elsewhere for now because of interface
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
      preload = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of models to preload on startup";
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
        listenAddress = "0.0.0.0";
        openFirewall = false; # Use granualrFirewall or manual set microvm rules
        port = ports.tcp.llama-swap;

        settings = {
          # Pre-download larger models and use -m if you don't want massive stalls
          # high health check timeout prevents it dying mid-download
          healthCheckTimeout = (time.minutes 60);
          globalTTL = cfg.ttl;

          models =
            if lib.elem "all" cfg.models then models else lib.filterAttrs (n: v: lib.elem n cfg.models) models;

          hooks.on_startup.preload = cfg.preload;

          # Define which models can be co-resident in memory
          # https://github.com/mostlygeek/llama-swap/issues/643
          # FIXME: This will differ on oedo vs ossa
          matrix = {
            vars = {
              # "qh" = "qwen3.6:27b-mtp-q4";
              "ql" = "Qwen 3.6 General 35B Q8 (Light)";
              "qul" = "Qwen 2.5 Coder 1.5B (Ultra Light)";
              "net" = "Nomic Embeddings";
            };

            sets = {
              standard = "ql & qul & net";
              # heavy = "qh & qul & net";
            };
          };
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
            # NOTE: Has 96gb dedicated to GPU set in bios, so no UMA
            lib.optionals (config.networking.hostName == "oedo") [
              # Strix Halo (gfx1151) ROCm tuning:
              "HSA_OVERRIDE_GFX_VERSION=11.5.1"
            ];
        };
      };

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
