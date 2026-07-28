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

-- Get git root by finding .git directory/file, walking upward from the file path.
-- Handles both regular repos (.git as directory) and worktrees (.git as file).
local function find_git_root(file_path)
  local dir = vim.fs.dirname(file_path)
  while dir and dir ~= "/" do
    local git_path = dir .. "/.git"
    -- Check if .git exists (either as directory or file)
    if vim.fn.isdirectory(git_path) == 1 or vim.fn.filereadable(git_path) == 1 then
      return dir
    end
    dir = vim.fs.dirname(dir)
  end
  return nil
end

-- Compute relative path by stripping the base path prefix
local function make_relative(file_path, base_path)
  if not base_path or base_path == "/" then
    return file_path
  end

  -- Ensure base_path ends with /
  if not base_path:match("/$") then
    base_path = base_path .. "/"
  end

  -- Check if file_path starts with base_path
  if file_path:sub(1, #base_path) == base_path then
    return file_path:sub(#base_path + 1)
  end

  return file_path
end

-- Relative path of the current file, preferring the git work tree root
-- and falling back to the path relative to cwd when outside a repo.
-- Handles diffview buffers specially.
function M.relative_path()
  local file_path

  -- Handle diffview buffers: extract the real file path from the URI
  local diffview_path = get_diffview_file()
  if diffview_path then
    file_path = diffview_path
  else
    file_path = vim.fn.expand("%:p")
  end

  -- Try to find git root by walking up from the file
  local git_root = find_git_root(file_path)
  if git_root then
    return make_relative(file_path, git_root)
  end

  -- Fallback: make relative to cwd
  return make_relative(file_path, vim.fn.getcwd())
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
