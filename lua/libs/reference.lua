-- Shared helpers for building references to the current file/line(s).
local M = {}

-- Relative path of the current file, preferring the git work tree root
-- (via fugitive) and falling back to the path relative to cwd when outside
-- a repo or before fugitive has loaded.
function M.relative_path()
  if vim.fn.exists("*FugitiveWorkTree") == 1 then
    local git_root = vim.fn.FugitiveWorkTree()
    if git_root ~= "" then
      return require("plenary.path"):new(vim.fn.expand("%:p")):make_relative(git_root)
    end
  end
  return vim.fn.expand("%:.")
end

-- Format a reference for the current file and a line/range.
function M.format(from, to)
  local path = M.relative_path()
  if to and to > from then
    return string.format("%s#L%d-L%d", path, from, to)
  end
  return string.format("%s#L%d", path, from)
end

-- Reference string for the current cursor line or, in visual mode, the
-- selected range: "path#L10" or "path#L45-L67". Leaves visual mode after
-- capturing the range so callers can safely move the cursor/window.
function M.line_ref()
  -- mode() still reports visual here because a Lua function rhs runs like
  -- <Cmd> and does not leave the current mode.
  if vim.fn.mode():match("[vV\22]") then
    local from, to = vim.fn.line("v"), vim.fn.line(".")
    if from > to then
      from, to = to, from
    end
    -- "x" flag processes the Esc synchronously, so a following startinsert is
    -- not cancelled by a queued Esc.
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    return M.format(from, to)
  end

  return M.format(vim.fn.line("."))
end

return M
