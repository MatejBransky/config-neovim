-- Tests for libs/code_notes/ref_parser.lua using mini.test
-- Run: nvim --headless -u NONE -l scripts/minitest.lua

package.path = vim.fn.stdpath("config") .. "/lua/?.lua;" .. package.path

local MiniTest = require("mini.test")
local T = MiniTest.new_set()

local ref_parser = require("libs.code_notes.ref_parser")

-- Stub resolve: accepts any string as a valid path
local function resolve(s) return s end

-- Helper to extract selected text from a line given start/end byte offsets
local function selected(line, s, e)
  return vim.trim(line):sub(s + 1, e + 1)
end

-- Helper: assert that parse_ref extracts `expected` from `line`
local function assert_extracted(line, expected)
  local ref, s, e = ref_parser.parse_ref(line, resolve)
  MiniTest.expect.no_equality(ref, nil)
  MiniTest.expect.equality(selected(line, s, e), expected)
end

-- Helper: assert that parse_ref returns nil
local function assert_no_ref(line)
  local ref = ref_parser.parse_ref(line, resolve)
  MiniTest.expect.equality(ref, nil)
end

T["backtick range"] = MiniTest.new_set()

T["backtick range"]["extracts content from `path#L10`"] = function()
  assert_extracted("`src/main.lua#L10`", "src/main.lua#L10")
end

T["backtick range"]["extracts content from `path#L10-L20`"] = function()
  assert_extracted("`src/main.lua#L10-L20`", "src/main.lua#L10-L20")
end

T["backtick range"]["finds ref inline"] = function()
  assert_extracted("see `src/main.lua#L10` for details", "src/main.lua#L10")
end

T["backtick range"]["whole file"] = function()
  assert_extracted("`foo.ts`", "foo.ts")
end

T["markdown link range"] = MiniTest.new_set()

T["markdown link range"]["extracts target from [label](path#L10)"] = function()
  assert_extracted("[label](src/main.lua#L10)", "src/main.lua#L10")
end

T["markdown link range"]["extracts target from [label](path#L10-L20)"] = function()
  assert_extracted("[label](src/main.lua#L10-L20)", "src/main.lua#L10-L20")
end

T["markdown link range"]["whole file"] = function()
  assert_extracted("[label](foo.ts)", "foo.ts")
end

T["markdown link range"]["first link wins on multi-link line"] = function()
  assert_extracted("[text](foo.ts#L1-L99) and [text2](bar.ts#L5)", "foo.ts#L1-L99")
end

T["markdown link range"]["label with parens"] = function()
  assert_extracted(
    "[registrace handleru (lifecycle event)](backend/jobs/scheduled/hostCampaignSequences/handleCampaignSequenceTriggerCheck.ts#L54)",
    "backend/jobs/scheduled/hostCampaignSequences/handleCampaignSequenceTriggerCheck.ts#L54")
end

T["markdown link range"]["backtick in label"] = function()
  assert_extracted(
    "- check-in: `SessionBookingCheckIns` (relace [`checkIn`](backend/db/entities/SessionBookings.ts#L315-L317))",
    "backend/db/entities/SessionBookings.ts#L315-L317")
end

T["bare ref"] = MiniTest.new_set()

T["bare ref"]["path#L10"] = function()
  assert_extracted("src/main.lua#L10", "src/main.lua#L10")
end

T["bare ref"]["path#L10-L20"] = function()
  assert_extracted("src/main.lua#L10-L20", "src/main.lua#L10-L20")
end

T["bare ref"]["inline range"] = function()
  assert_extracted(
    "ssioiuois .agents/data/CU-868khn622-implementation-plan.md#L3-L6 lkjlksjlkjlkdjjlkd",
    ".agents/data/CU-868khn622-implementation-plan.md#L3-L6")
end

T["bare ref"]["inline"] = function()
  assert_extracted("see src/main.lua#L10 for details", "src/main.lua#L10")
end

T["bare ref"]["whole file"] = function()
  assert_extracted("src/main.lua", "src/main.lua")
end

T["bare ref"]["whole file inline"] = function()
  assert_extracted(
    "backend/routes/member-portal/userCancelNetflixSubscription.ts lkjlkjlkj",
    "backend/routes/member-portal/userCancelNetflixSubscription.ts")
end

T["no ref"] = MiniTest.new_set()

T["no ref"]["plain text"] = function()
  assert_no_ref("just some text")
end

T["no ref"]["empty"] = function()
  assert_no_ref("")
end

return T
