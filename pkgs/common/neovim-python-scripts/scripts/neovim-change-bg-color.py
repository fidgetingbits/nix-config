#!/usr/bin/env python
import os
import sys
import pathlib

try:
    import pynvim
except Exception:
    # Avoid warning multiple times by checking our parent process
    folder = "/var/run/neovim-python-scripts"
    pathlib.Path(folder).mkdir(parents=True, exist_ok=True)
    complained = pathlib.Path(f"{folder}/complained.{os.environ.get('NVIM')}")
    if not complained.exists():
        complained.touch()
        print(f"ERROR: Script {sys.argv[0]} requires the 'pynvim' package.")
        print("ERROR: This may be a virtualenv python mismatch itch you")
        raise

try:
    nvim = pynvim.attach("socket", path=os.environ["NVIM"])
except KeyError:
    # We aren't under vim, just exit
    sys.exit(0)

if len(sys.argv) == 2:
    color = sys.argv[1]
    # See :help winhighlight
    # nvim.command('execute "set winhighlight=Normal:TermBg"')
    nvim.command('execute "set winhighlight=SignColumn:TermBg"')

    nvim.command(f'execute "highlight TermBg guibg={color}"')
else:
    print("Usage: neovim-change-bgcolor.py <color>")
    sys.exit(1)
