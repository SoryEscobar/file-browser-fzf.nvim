#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Starting Neovim sandbox with fzf-lua-file-browser.nvim..."
exec nvim -u "$SCRIPT_DIR/init.lua" "$@"
