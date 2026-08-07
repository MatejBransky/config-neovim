-- Tests for per-project code notes persistence.
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

T["storage"] = MiniTest.new_set()

T["storage"]["saves and loads notes for the current project"] = function()
  local original_cwd = vim.fn.getcwd()
  local original_storage = notes.config.storage_dir
  local cwd = new_dir()
  local storage = new_dir()

  notes.setup({ storage_dir = storage })
  vim.fn.chdir(cwd)
  notes.open()
  vim.api.nvim_buf_set_lines(notes.bufnr, 0, -1, false, { "project note" })
  notes.save()
  vim.api.nvim_buf_set_lines(notes.bufnr, 0, -1, false, {})
  vim.bo[notes.bufnr].modified = false
  notes.load()

  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(notes.bufnr, 0, -1, false), { "project note" })

  vim.fn.chdir(original_cwd)
  notes.setup({ storage_dir = original_storage })
  vim.fn.delete(cwd, "d")
  vim.fn.delete(storage, "rf")
end

T["storage"]["tracks edits as unsaved changes"] = function()
  local original_cwd = vim.fn.getcwd()
  local original_storage = notes.config.storage_dir
  local cwd = new_dir()
  local storage = new_dir()

  notes.setup({ storage_dir = storage })
  vim.fn.chdir(cwd)
  notes.open()
  vim.api.nvim_buf_set_lines(notes.bufnr, 0, -1, false, { "unsaved note" })

  MiniTest.expect.equality(vim.bo[notes.bufnr].modified, true)

  vim.fn.chdir(original_cwd)
  notes.setup({ storage_dir = original_storage })
  vim.fn.delete(cwd, "d")
  vim.fn.delete(storage, "rf")
end

T["storage"]["uses markdown syntax without a markdown filetype"] = function()
  local original_cwd = vim.fn.getcwd()
  local original_storage = notes.config.storage_dir
  local cwd = new_dir()
  local storage = new_dir()

  notes.setup({ storage_dir = storage })
  vim.fn.chdir(cwd)
  notes.open()

  MiniTest.expect.equality(vim.bo[notes.bufnr].filetype, "code_notes")
  MiniTest.expect.equality(vim.bo[notes.bufnr].syntax, "markdown")

  vim.fn.chdir(original_cwd)
  notes.setup({ storage_dir = original_storage })
  vim.fn.delete(cwd, "d")
  vim.fn.delete(storage, "rf")
end

T["storage"]["does not close when the user cancels"] = function()
  local original_cwd = vim.fn.getcwd()
  local original_storage = notes.config.storage_dir
  local original_confirm = vim.fn.confirm
  local cwd = new_dir()
  local storage = new_dir()

  notes.setup({ storage_dir = storage })
  vim.fn.chdir(cwd)
  notes.open()
  vim.api.nvim_buf_set_lines(notes.bufnr, 0, -1, false, { "keep me" })
  local notes_win = vim.api.nvim_get_current_win()
  local prompt
  local title
  vim.fn.confirm = function(message, _, _, dialog_title)
    prompt = message
    title = dialog_title
    return 3
  end

  notes.close()

  MiniTest.expect.equality(vim.api.nvim_win_is_valid(notes_win), true)
  MiniTest.expect.equality(title, "Code Notes")
  MiniTest.expect.equality(prompt:match("Unsaved changes in:"), "Unsaved changes in:")
  MiniTest.expect.equality(prompt:match("Save these notes before closing%?"), "Save these notes before closing?")
  vim.fn.confirm = original_confirm
  vim.fn.chdir(original_cwd)
  notes.setup({ storage_dir = original_storage })
  vim.fn.delete(cwd, "d")
  vim.fn.delete(storage, "rf")
end

T["storage"]["keeps notes separate for different working directories"] = function()
  local original_cwd = vim.fn.getcwd()
  local original_storage = notes.config.storage_dir
  local first = new_dir()
  local second = new_dir()
  local storage = new_dir()

  notes.setup({ storage_dir = storage })
  vim.fn.chdir(first)
  notes.open()
  vim.api.nvim_buf_set_lines(notes.bufnr, 0, -1, false, { "first" })
  notes.save()

  vim.fn.chdir(second)
  notes.open()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(notes.bufnr, 0, -1, false), { "" })
  vim.api.nvim_buf_set_lines(notes.bufnr, 0, -1, false, { "second" })
  notes.save()

  vim.fn.chdir(first)
  notes.open()
  MiniTest.expect.equality(vim.api.nvim_buf_get_lines(notes.bufnr, 0, -1, false), { "first" })

  vim.fn.chdir(original_cwd)
  notes.setup({ storage_dir = original_storage })
  vim.fn.delete(first, "d")
  vim.fn.delete(second, "d")
  vim.fn.delete(storage, "rf")
end

return T
