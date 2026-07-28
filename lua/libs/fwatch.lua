local M = {}
local uv = vim.uv

-- Helper function to get file content hash for change detection
local function get_file_hash(path)
  local content = vim.fn.readfile(path)
  if not content then
    return nil
  end
  return vim.fn.sha256(table.concat(content, "\n"))
end

-- Main watch function that returns an unwatch handle
M.watch = function(path, callback)
  if not path or not callback then
    error("fwatch.watch requires path and callback")
  end

  local stat = uv.fs_stat(path)
  if not stat then
    error("Path does not exist: " .. path)
  end

  local is_file = stat.type == "file"
  
  if not is_file then
    error("fwatch only supports file watching, not directories")
  end

  local fs_event = uv.new_fs_event()
  if not fs_event then
    error("Failed to create file system event watcher")
  end

  local last_known_hash = nil

  -- Initialize last known state
  if is_file then
    last_known_hash = get_file_hash(path)
  end

  local on_change = function(err, filename, events)
    if err then
      vim.schedule(function()
        vim.print("fwatch error: " .. err)
      end)
      return
    end

    local current_hash = get_file_hash(path)
    if current_hash ~= last_known_hash then
      last_known_hash = current_hash
      pcall(callback, path, events)
    end
  end

  local watch_path = vim.fn.fnamemodify(path, ":h")
  local ok, err = fs_event:start(watch_path, { recursive = false }, vim.schedule_wrap(on_change))

  if ok ~= 0 then
    error("Failed to start watcher: " .. (err or "unknown error"))
  end

  -- Return unwatch function
  local unwatch = function()
    if fs_event then
      fs_event:stop()
      fs_event:close()
    end
  end

  return unwatch
end



return M
