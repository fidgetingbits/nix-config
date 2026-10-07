{
  pkgs,
  inputs,
  config,
  osConfig,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.dictation;
  llamaSwapPort = osConfig.hostSpec.networking.ports.tcp.llama-swap;
  summaryEndpointPort = 8080;
  meetingSummaryEndpoint =
    pkgs.writers.writePython3Bin "meeting-summary"
      { libraries = lib.attrValues { inherit (pkgs.python3Packages) flask requests; }; } # python
      ''
        from flask import Flask, request, jsonify
        import requests

        app = Flask(__name__)
        LLAMA_SWAP = "http://oedo.${osConfig.hostSpec.domain}:${toString llamaSwapPort}/v1/chat/completions"


        @app.route("/api/summarize", methods=["POST", "HEAD"])
        def summarize():
            if request.method == "HEAD":
                return "", 200
            data = request.get_json() or {}
            # Voxtype posts the raw transcript string or transcript object
            prompt_text = data.get("prompt", "")

            payload = {
                "model": "gemma-4:26b-a4b-q6",
                "messages": [
                    {"role": "user", "content": prompt_text}
                ],
                "temperature": 0.3
            }
            r = requests.post(LLAMA_SWAP, json=payload, timeout=120)
            summary_text = r.json()["choices"][0]["message"]["content"]

            # Return directly to Voxtype
            return jsonify({"summary": summary_text})


        if __name__ == "__main__":
            app.run(host="127.0.0.1", port=${toString summaryEndpointPort})
      '';
in
{
  options.${namespace}.dictation = {
    enable = lib.mkEnableOption "Add dictation tooling";
  };

  imports = [ inputs.voxtype.homeManagerModules.default ];

  config = lib.mkIf cfg.enable {
    programs.voxtype = {
      enable = true;
      service.enable = true;

      # Only using this on AMD systems atm. rocm crashes
      # package = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
      package = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.onnx-migraphx;
      # inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.onnx-migraphx.overrideAttrs
      #   (oldAttrs: {
      #     cargoFeatures = (oldAttrs.cargoFeatures or [ ]) ++ [ "ml-diarization" ];
      #   });

      # FIXME: there is an alibaba model that does chinese/english, which we may want to situationally have?
      settings = {
        # We need onnx-migraphx for ml diaraization, but that means only parakeet gets GPU acceleration
        # NOTE: 1) You will have to run voxtype setup to download the model
        # NOTE: 2) The first run will compile a kernel, so will still seem slow
        engine = "parakeet";
        # engine = "whisper"; Enable if using vulkan and not onnx-migraphx
        whisper = {
          model = "base.en";
          language = "en";
        };

        parakeet = {
          # English only: parakeet-unified-en-0.6b
          # Multi-language: parakeet-tdt-0.6b-v3
          # model = "parakeet-unified-en-0.6b";
          model = "parakeet-tdt-0.6b-v3";
          model_type = "tdt";
        };

        meeting = {
          enabled = true;
          summary = {
            backend = "remote";
            remote_endpoint = "http://localhost:${toString summaryEndpointPort}/api/summarize";
            remote_api_key = "foo";
          };
        };

        output = {
          mode = "type";
          fallback_to_clipboard = true;

          notifications = {
            on_recording_start = true;
            on_recording_stop = true;
            on_transcription = false;
          };
        };
        # using noctalia plugin
        osd.enabled = false;
      };
    };

    systemd.user.services.voxtype-summarize = {
      Unit = {
        description = "voxtype Meeting Summary API Service";
        After = [
          "graphical-session.target"
          "graphical-session-pre.target"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = lib.getExe meetingSummaryEndpoint;
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
