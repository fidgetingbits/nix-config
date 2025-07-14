# Good reference: https://github.com/mjmaurer/infra/blob/8e26748b64b2ca4a19603ae0b4f9ab759ba98b3e/home-manager/modules/vscode/keybindings.nix#L19
[
  {
    command = "workbench.panel.chat.view.copilot.focus";
    key = "ctrl+'";
    when = "editorFocus";
  }
  {
    command = "workbench.action.focusActiveEditorGroup";
    key = "ctrl+'";
    when = "!editorFocus";
  }
]
