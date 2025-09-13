# There is a special syntax for translating to KDL
# nix example:
# https://github.com/khaneliman/khanelinix/blob/a3dba22a3194f42b9ad606dd709449b8d7b6d04d/modules/home/programs/terminal/tools/zellij/keybinds.nix

# Original kdl file with alt bindings
# https://github.com/gmr458/.dotfiles/blob/69ea4a9e9efae48cb1f9cf131165bcfd03fd16f1/zellij/.config/zellij/config.kdl#L4
{
  # This clears all default keybindings to start fresh.
  _props.clear-defaults = true;
}
