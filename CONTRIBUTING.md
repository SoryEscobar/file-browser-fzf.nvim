# Contributing to `fzf-lua-file-browser.nvim`

First off, thank you for considering contributing to `fzf-lua-file-browser.nvim`! We welcome bug fixes, documentation improvements, feature requests, and pull requests.

## 🚀 Getting Started & Local Setup

1. Fork and clone the repository locally:
   ```bash
   git clone https://github.com/<your-username>/fzf-lua-file-browser.nvim.git
   cd fzf-lua-file-browser.nvim
   ```

2. **Running Unit & Integration Tests**:
   The plugin comes with an automated headless test suite (`./tests/run_all.sh`) using clean Neovim headless instances:
   ```bash
   ./tests/run_all.sh
   ```
   Ensure all tests pass before opening a pull request.

3. **Interactive Sandbox Testing**:
   You can launch an isolated Neovim session loaded with your local modifications using our sandbox script:
   ```bash
   ./sandbox/run.sh
   ```

## 📐 Code Style & Architecture

- **Lua Version**: Compatible with LuaJIT 5.1 (standard for Neovim `>= 0.9.0`).
- **Zero Telescope Dependencies**: Ensure all picker, finder, and previewer actions rely strictly on `fzf-lua` APIs and native Neovim standard library.
- **Keybinds & Actions**: When adding new actions in `lua/fzf-lua-file-browser/actions.lua`, ensure they:
  - Support multi-selection where appropriate.
  - Properly handle cancellation (`on_cancel`) without dropping the user out of the picker.
  - Are documented in `doc/fzf-lua-file-browser.txt`, `README.md`, and the `<C-k>` cheat sheet.

## 📬 Pull Request Guidelines

1. Create a descriptive feature branch (`feat/your-feature` or `fix/issue-name`).
2. Add unit tests in `tests/` covering any new functionality or bug fixes.
3. Keep commit messages clean and conventional (`feat: ...`, `fix: ...`, `docs: ...`).
