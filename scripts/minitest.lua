-- Script for running mini.test tests
-- Usage: nvim --headless -u NONE -l scripts/minitest.lua

local config_dir = vim.fn.stdpath("config")
vim.opt.rtp:prepend(config_dir)
vim.opt.rtp:prepend(config_dir .. "/deps/mini.test")
vim.opt.rtp:prepend(config_dir .. "/deps/mini.nvim")

local MiniTest = require("mini.test")
MiniTest.setup({
  collect = {
    find_files = function()
      return vim.fn.globpath(config_dir .. "/tests", "**/test_*.lua", true, true)
    end,
  },
})

MiniTest.run()
