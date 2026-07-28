# 💤 Neovim Config

Personal [LazyVim](https://github.com/LazyVim/LazyVim)-based Neovim configuration with custom enhancements.

## What's Added/Customized

### Core Features
- **Centralized keybindings** — all keymaps defined in `lua/keybindings.lua` as a data structure for easy reference
- **Disabled tabline** — cleaner UI (`:set showtabline=0`)
- **Spell check disabled** — in markdown and text files by default
- **Highlight-on-yank fix** — compatibility with nvim-0.13-dev

### Utility Modules
- **fwatch.lua** — file watching with debouncing
- **code_notes.lua** — scratch buffer for collecting code references and notes
- **colorscheme_sync.lua** — sync colorscheme across applications
- **reference.lua** — copy file/git references with diffview support

### Enhanced Features
- **Diffview integration** — code-notes properly extracts references from diffview buffers (bare worktree support included)
- **Custom keymaps** — macro recording (`<A-q>`), diff windows (`<leader>dw`, `<leader>dq`)
- **Plugin configurations** — AI (Copilot), LSP, git tools, statusline, notes, and UI enhancements

### Disabled/Modified
- Macro recording via `q` — use `<A-q>` instead
