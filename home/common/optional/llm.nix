{ pkgs, ... }:
{
  home.packages = [
    pkgs.llm # online inference (llama-swap, claude, gemini, openai, etc)
    pkgs.llama-cpp # offline inference (llama, deepseek, qwen, etc)
  ];
}
