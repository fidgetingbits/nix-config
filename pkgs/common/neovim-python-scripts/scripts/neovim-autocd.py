#!/usr/bin/env python

# Automatically change neovim's working directory via
# the built in terminal.

import os

try:
    import pynvim
except Exception:
    print("WARNING: Your shell is probably inside of a venv?")
    raise


nvim = pynvim.attach("socket", path=os.environ["NVIM"])
nvim.vars["__autocd_cwd"] = os.getcwd()
nvim.command('execute "lcd" fnameescape(g:__autocd_cwd)')
del nvim.vars["__autocd_cwd"]
