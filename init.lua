package.path = package.path .. ";" .. vim.fn.expand("~/.config/pde/?.lua")
-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
