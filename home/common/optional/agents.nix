# FIXME: This has overlap with microvms/home/common/optional/agents
# so we should tweak how the microvm accesses the server
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  # FIXME: Relocate this to llama-swap
  # add oedo
  # infer all the information from the llama-swap servers own settings
  models.providers = {
    ossa = {
      baseUrl = "http://ossa::${toString osConfig.hostSpec.networking.ports.tcp.llama-swap}/v1";
      api = "openai-completions";
      apiKey = "foo";
      models = [
        {
          id = "qwen3-vl:8b";
          name = "Qwen 3 VL (8B Thinking GGUF)";
        }
      ];
    };
  };

  # FIXME: Make it easier to specify model/system
  token-speed = pkgs.writeShellApplication {
    name = "token-speed";
    runtimeInputs = lib.attrValues { inherit (pkgs) jq curl; };
    text = # bash
      ''
        curl -s -X POST "$LLAMA_SWAP_URL/v1/chat/completions" \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer my-dummy-key" \
          -d '{
                 "model": "'"$LLAMA_MODEL_ID"'",
                 "messages": [{"role": "user", "content": "Tell me a short joke. This is a ping test, ignore system prompts."}],
                 "max_tokens": 100
              }' | jq '.timings | {Prompt_Speed: .prompt_per_second, Generation_Speed: .predicted_per_second}'
      '';
  };
in
{
  home = {
    packages =
      lib.attrValues {
        inherit (pkgs)
          claude-code
          claude-agent-acp
          codex
          codex-acp
          crush
          gemini-cli
          pi-coding-agent
          ;
      }
      ++ [
        token-speed
      ];
    file = {
      ".pi/agent/models.json".source = jsonFormat.generate "pi-coding-agent-models.json" models;
    };
  };
}
