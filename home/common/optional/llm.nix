{ pkgs, ... }:
{
  home.packages = [
    pkgs.llm # online inference (claude, gemini, gpt, etc)
    pkgs.llama-cpp # offline inference (llama, deepseek, qwen, etc)
  ];
}
