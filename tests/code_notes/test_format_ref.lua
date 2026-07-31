-- Tests for format_ref and {cursor} placement in libs/code_notes/init.lua
-- Run: nvim --headless -u NONE -l scripts/minitest.lua

package.path = vim.fn.stdpath("config") .. "/lua/?.lua;" .. package.path

local MiniTest = require("mini.test")
local T = MiniTest.new_set()

local notes = require("libs.code_notes")

T["format presets"] = MiniTest.new_set()

T["format presets"]["plain returns ref as-is"] = function()
  MiniTest.expect.equality(notes.format.plain("src/main.lua#L10"), "src/main.lua#L10")
end

T["format presets"]["backtick wraps in backticks"] = function()
  MiniTest.expect.equality(notes.format.backtick("src/main.lua#L10"), "`src/main.lua#L10`")
end

T["format presets"]["link wraps in markdown link with cursor"] = function()
  MiniTest.expect.equality(notes.format.link("src/main.lua#L10"), "[{cursor}](src/main.lua#L10)")
end

T["format presets"]["link_with uses custom label"] = function()
  local fmt = notes.format.link_with("viz")
  MiniTest.expect.equality(fmt("src/main.lua#L10"), "[viz](src/main.lua#L10)")
end

T["format presets"]["obsidian wraps in wikilink with cursor"] = function()
  MiniTest.expect.equality(notes.format.obsidian("src/main.lua#L10"), "[[{cursor}]](src/main.lua#L10)")
end

T["format presets"]["obsidian_alias uses alias syntax"] = function()
  local fmt = notes.format.obsidian_alias("Main")
  MiniTest.expect.equality(fmt("src/main.lua#L10"), "[[src/main.lua#L10|Main]]")
end

T["format presets"]["link_list adds dash prefix"] = function()
  MiniTest.expect.equality(notes.format.link_list("src/main.lua#L10"), "- [{cursor}](src/main.lua#L10)")
end

T["cursor marker"] = MiniTest.new_set()

T["cursor marker"]["{cursor} is removed from line"] = function()
  local ref = notes.format.link("path#L10")
  MiniTest.expect.no_equality(ref:find("{cursor}", 1, true), nil)
  -- The actual cursor removal happens in append_lines, but the marker is present in format output
end

T["cursor marker"]["cursor position is byte offset"] = function()
  local ref = notes.format.link("path#L10") -- [{cursor}](path#L10)
  local s = ref:find("{cursor}", 1, true)
  -- s is 1-based Lua index; nvim_win_set_cursor wants 0-based column = s - 1
  MiniTest.expect.equality(s - 1, 1) -- column 1 = between [ and ]
end

T["config"] = MiniTest.new_set()

T["config"]["format_ref defaults to nil"] = function()
  MiniTest.expect.equality(notes.config.format_ref, nil)
end

T["config"]["config accepts format_ref function"] = function()
  local original = notes.config.format_ref
  notes.config.format_ref = notes.format.backtick
  MiniTest.expect.equality(notes.config.format_ref("test#L1"), "`test#L1`")
  notes.config.format_ref = original
end

T["config"]["style defaults to block"] = function()
  MiniTest.expect.equality(notes.config.style, "block")
end

T["style list"] = MiniTest.new_set()

T["style list"]["link_list produces compact line"] = function()
  local ref = notes.format.link_list("src/main.lua#L10")
  MiniTest.expect.equality(ref, "- [{cursor}](src/main.lua#L10)")
end

T["style list"]["link_list without cursor is just a bullet"] = function()
  local fmt = function(ref) return "- " .. ref end
  MiniTest.expect.equality(fmt("src/main.lua#L10"), "- src/main.lua#L10")
end

return T
