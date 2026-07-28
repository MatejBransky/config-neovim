local keybindings = require("keybindings")

vim.keymap.set("n", "q", "<Nop>", { desc = "Macro recording disabled, use <A-q>" })

vim.keymap.set({ "n", "x" }, "<A-q>", "q", { desc = "Macro recording" })

vim.keymap.set(
  { "n" },
  keybindings.misc.diffWin.shortcut,
  "<Cmd>windo diffthis<CR>",
  { desc = keybindings.misc.diffWin.desc }
)
vim.keymap.set(
  { "n" },
  keybindings.misc.diffWinQuit.shortcut,
  "<Cmd>windo diffoff<CR>",
  { desc = keybindings.misc.diffWinQuit.desc }
)

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
