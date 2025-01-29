#!/usr/bin/env python
import os
import sys

try:
    import pynvim
except Exception:
    print("WARNING: Your shell is probably inside of a venv?")
    raise

nvim = pynvim.attach("socket", path=os.environ["NVIM"])

if len(sys.argv) <= 1:
    nvim.command('execute "enew"')
# This is because of some zsh autocompletion bug
elif sys.argv[1] == "--version":
    sys.exit(1)
else:
    nvim.command(f'execute "tabedit {sys.argv[1]}"')
