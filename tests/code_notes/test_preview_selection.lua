-- Regression tests for the lifecycle of range previews in code notes.
-- Run: nvim --headless -u NONE -l scripts/minitest.lua

package.path = vim.fn.stdpath("config") .. "/lua/?.lua;" .. package.path

local MiniTest = require("mini.test")
local T = MiniTest.new_set()
local notes = require("libs.code_notes")

local function new_dir()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, "p")
  return path
end

local function target_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) ~= notes.bufnr then
      return win
    end
  end
end

T["range preview"] = MiniTest.new_set()

T["range preview"]["is cleared when entering the referenced buffer"] = function()
  local original_cwd = vim.fn.getcwd()
  local cwd = new_dir()
  local storage = new_dir()
  local file = cwd .. "/source.lua"
  vim.fn.writefile({ "one", "two", "three", "four" }, file)

  if #vim.api.nvim_list_wins() > 1 then
    vim.cmd("only")
  end
  vim.fn.chdir(cwd)
  notes.setup({ storage_dir = storage })
  notes.open()
  vim.api.nvim_buf_set_lines(notes.bufnr, 0, -1, false, { "source.lua#L2-L3" })
  notes.goto_ref(1)

  local win = target_window()
  local target_buf = vim.api.nvim_win_get_buf(win)
  local namespace = vim.api.nvim_get_namespaces()["code_notes.preview"]
  local preview = vim.api.nvim_buf_get_extmarks(target_buf, namespace, 0, -1, {})
  MiniTest.expect.equality(#preview > 0, true)

  vim.api.nvim_set_current_win(win)

  MiniTest.expect.equality(vim.api.nvim_buf_get_extmarks(target_buf, namespace, 0, -1, {}), {})

  vim.fn.chdir(original_cwd)
  notes.setup({ storage_dir = storage })
  vim.fn.delete(cwd, "d")
  vim.fn.delete(storage, "rf")
end

return T
