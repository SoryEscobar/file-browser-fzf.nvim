#!/usr/bin/env bash
set -e

echo "Running all fzf-lua-file-browser tests..."

nvim --headless -u tests/minimal_init.lua -l tests/test_utils.lua
nvim --headless -u tests/minimal_init.lua -l tests/test_finder.lua
nvim --headless -u tests/minimal_init.lua -l tests/test_actions.lua
nvim --headless -u tests/minimal_init.lua -l tests/test_netrw.lua
nvim --headless -u tests/minimal_init.lua -l tests/test_fzf_integration.lua

echo "========================================="
echo "ALL TESTS PASSED SUCCESSFULLY!"
echo "========================================="
