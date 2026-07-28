-- Shared helpers for building references to the current file/line(s).
local M = {}

-- Extract the real file path from a diffview buffer URI.
-- diffview:///path/to/file turns into /path/to/file
local function extract_diffview_path(uri)
  local path = uri:match("^diffview://(.*)$")
  if path then
    return path
  end
  return nil
end

-- Detect if the current buffer is a diffview buffer and extract the real file path.
-- Diffview buffers show file paths after the last "/" in the buffer name.
local function get_diffview_file()
  local bufname = vim.fn.bufname("%")
  if bufname:find("diffview://", 1, true) then
    local real_path = extract_diffview_path(bufname)
    if real_path then
      return real_path
    end
  end
  return nil
end

-- Relative path of the current file, preferring the git work tree root
-- (via fugitive) and falling back to the path relative to cwd when outside
-- a repo or before fugitive has loaded. Handles diffview buffers specially.
function M.relative_path()
  local file_path

  -- Handle diffview buffers: extract the real file path from the URI
  local diffview_path = get_diffview_file()
  if diffview_path then
    file_path = diffview_path
  else
    file_path = vim.fn.expand("%:p")
  end

  -- Try to make relative to git root first
  if vim.fn.exists("*FugitiveWorkTree") == 1 then
    local git_root = vim.fn.FugitiveWorkTree()
    if git_root ~= "" then
      return require("plenary.path"):new(file_path):make_relative(git_root)
    end
  end

  -- Fallback: make relative to cwd
  return require("plenary.path"):new(file_path):make_relative(vim.fn.getcwd())
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
