#!/usr/bin/env python
import os
import sys

import neovim

if len(sys.argv) <= 2:
    print("ERROR: provide at least two files")
    sys.exit(1)

nvim = neovim.attach("socket", path=os.environ["NVIM"])
nvim.command('execute "diff {}"'.format(sys.argv[1:]))
