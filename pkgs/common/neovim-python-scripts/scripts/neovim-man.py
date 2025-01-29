#!/usr/bin/env python
import os
import sys

import neovim

if len(sys.argv) <= 1:
    print("ERROR: provide at least one argument")
    sys.exit(1)

nvim = neovim.attach("socket", path=os.environ["NVIM"])
nvim.command('execute ":Man {}"'.format(sys.argv[1]))
