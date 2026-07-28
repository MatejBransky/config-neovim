local fwatch = require("libs.fwatch")

local sync_dir = os.getenv("HOME") .. "/.config/wezterm/colorscheme"

local constants = {
  PRESETS_PATH = sync_dir .. "/presets.json",
  CONFIG_PATH = sync_dir .. "/preset.config.json",
  THEME_PATH = sync_dir .. "/theme",
}

local module = {}

-- ---------- helpers ----------

local function read_presets()
  local f = io.open(constants.PRESETS_PATH, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    return nil
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end
  return data.presets
end

local function resolve_scheme(preset, theme)
  local presets = read_presets()

  if not presets then
    return nil
  end
  local p = presets[preset]
  if not p then
    return nil
  end
  return p.neovim[theme]
end

local function read_config()
  local f = io.open(constants.CONFIG_PATH, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    return nil
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end
  return data
end

local function read_theme()
  local f = io.open(constants.THEME_PATH, "r")
  if not f then
    return nil
  end
  local t = f:read("*l")
  f:close()
  return t
end

function module.sync_theme()
  local theme = read_theme()
  if not theme then
    return
  end
  vim.api.nvim_set_option_value("background", theme, {})
end

function module.sync_scheme()
  local config = read_config()
  if not config then
    return
  end
  local preset = config.preset
  local theme = read_theme()
  if not theme then
    return
  end
  local scheme = resolve_scheme(preset, theme)
  if not scheme then
    return
  end
  vim.cmd("colorscheme " .. scheme)
end

function module.watch_theme_changes()
  local unwatch = fwatch.watch(constants.THEME_PATH, function()
    vim.schedule(function()
      module.sync_theme()
    end)
  end)

  return unwatch
end

function module.watch_config_changes()
  local unwatch = fwatch.watch(constants.CONFIG_PATH, function()
    vim.schedule(function()
      module.sync_scheme()
    end)
  end)

  return unwatch
end

return module
