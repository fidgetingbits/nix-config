#!/usr/bin/env python
import os
import sys

try:
    import pynvim
except Exception:
    print("WARNING: Your shell is probably inside of a venv?")
    raise

if len(sys.argv) <= 1:
    print("ERROR: provide at least one file")
    sys.exit(1)

nvim = pynvim.attach("socket", path=os.environ["NVIM"])
nvim.command(f'execute "edit {sys.argv[1]}"')
