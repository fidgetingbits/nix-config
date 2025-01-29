#!/usr/bin/env bash
set -euo pipefail

# I have to use one repo for building cursorless.nvim into nixvim that uses a stable commit, but I also need to update
# the node packages constantly as I do development, so this helps automate it

STABLE=/home/aa/dev/talon/cursorless-neovim/cursorless.nvim/node/
DEV=/home/aa/dev/talon/fidgetingbits-cursorless
TEST=test-harness
NVIM=cursorless-neovim

cd ${DEV}
pnpm build

cp packages/${NVIM}/package.json ${STABLE}/${NVIM}/package.json
mkdir -p ${STABLE}/${NVIM}/out || true
cp packages/${NVIM}/out/index.cjs ${STABLE}/${NVIM}/out/index.cjs

cp packages/${TEST}/package.json ${STABLE}/${TEST}/package.json
mkdir -p ${STABLE}/${TEST}/out || true
cp packages/${TEST}/out/index.cjs ${STABLE}/${TEST}/out/index.cjs

cd ${STABLE}/
git add -f ${NVIM}/package.json ${NVIM}/out/index.cjs ${TEST}/package.json ${TEST}/out/index.cjs
