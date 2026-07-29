-- Scratch "code notes" buffer: collect references to file locations together
-- with free-form notes, then copy/save the result (e.g. to hand to an AI agent).
-- Supports jumping back to a reference (<CR>) and cycling between references
-- (<Tab>/<S-Tab>) from inside the notes buffer.
local reference = require("libs.reference")
local keybindings = require("keybindings")

local M = {}

-- bufnr of the persistent notes buffer (nil until first use)
M.bufnr = nil

-- User-tunable config (see lua/plugins/notes.lua opts).
M.config = {
  -- Divider inserted between entries. "" means only a blank line.
  separator = "---",
  -- Prefix code snippets with their file reference line (path#L3-L4), which
  -- also makes snippets navigable/jumpable like plain references.
  snippet_include_ref = true,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

local NAME = "code-notes.md"

-- Project root used to resolve the relative references back to absolute paths:
-- the git top-level of cwd, falling back to cwd itself.
local function project_root()
  local dot_git = vim.fs.find(".git", { upward = true, path = vim.fn.getcwd() })[1]
  if dot_git then
    return vim.fs.dirname(dot_git)
  end
  return vim.fn.getcwd()
end

-- Resolve a relative reference path to a readable absolute path, or nil.
local function resolve(rel)
  for _, base in ipairs({ project_root(), vim.fn.getcwd() }) do
    local abs = base .. "/" .. rel
    if vim.fn.filereadable(abs) == 1 then
      return vim.fn.fnamemodify(abs, ":p")
    end
  end
  return nil
end

-- Parse a notes line into { path, from?, to? } when it is a reference, else nil.
local function parse_ref(line)
  local s = vim.trim(line)

  local path, from, to = s:match("^(%S+)#L(%d+)%-L(%d+)$")
  if path then
    return { path = path, from = tonumber(from), to = tonumber(to) }
  end

  path, from = s:match("^(%S+)#L(%d+)$")
  if path then
    return { path = path, from = tonumber(from) }
  end

  -- whole-file reference: a lone token that resolves to a real file
  if s:match("^%S+$") and resolve(s) then
    return { path = s }
  end

  return nil
end

-- Line numbers (1-based) of every reference in the notes buffer.
local function ref_lines(buf)
  local out = {}
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if parse_ref(line) then
      table.insert(out, i)
    end
  end
  return out
end

-- A window suitable for showing a referenced file: the window we came from,
-- otherwise any non-notes window, otherwise a fresh split.
local function target_window(notes_win)
  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  if prev ~= 0 and prev ~= notes_win and vim.api.nvim_win_is_valid(prev) then
    return prev
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= notes_win and vim.api.nvim_win_get_buf(win) ~= M.bufnr then
      return win
    end
  end
  vim.cmd("leftabove vsplit")
  return vim.api.nvim_get_current_win()
end

-- Jump to the reference on the current notes line in the adjacent window.
function M.jump()
  local notes_win = vim.api.nvim_get_current_win()
  local parsed = parse_ref(vim.api.nvim_get_current_line())
  if not parsed then
    vim.notify("No reference on this line", vim.log.levels.WARN)
    return
  end

  local abs = resolve(parsed.path)
  if not abs then
    vim.notify("File not found: " .. parsed.path, vim.log.levels.WARN)
    return
  end

  local win = target_window(notes_win)
  vim.api.nvim_set_current_win(win)
  vim.cmd("edit " .. vim.fn.fnameescape(abs))

  local from = parsed.from or 1
  if parsed.to and parsed.to > from then
    -- land on the range with it selected linewise
    vim.cmd(string.format("normal! %dGV%dGzz", from, parsed.to))
  else
    vim.api.nvim_win_set_cursor(win, { from, 0 })
    vim.cmd("normal! zz")
  end
end

-- Move to and select (linewise) the next/previous reference. dir = 1 | -1.
function M.goto_ref(dir)
  local buf = M.bufnr
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  local refs = ref_lines(buf)
  if #refs == 0 then
    vim.notify("No references yet", vim.log.levels.WARN)
    return
  end

  -- leave any active selection before repositioning
  if vim.fn.mode():match("[vV\22]") then
    vim.cmd("normal! \27")
  end

  local notes_win = vim.api.nvim_get_current_win()
  local cur = vim.api.nvim_win_get_cursor(notes_win)[1]
  local target
  if dir == 1 then
    for _, l in ipairs(refs) do
      if l > cur then
        target = l
        break
      end
    end
    target = target or refs[1] -- wrap around
  else
    for i = #refs, 1, -1 do
      if refs[i] < cur then
        target = refs[i]
        break
      end
    end
    target = target or refs[#refs] -- wrap around
  end

  vim.api.nvim_win_set_cursor(notes_win, { target, 0 })

  -- Preview the referenced file in the adjacent window, keeping focus here so
  -- the user can keep cycling; <CR> is what actually moves the cursor there.
  local parsed = parse_ref(vim.api.nvim_buf_get_lines(buf, target - 1, target, false)[1])
  if parsed then
    local abs = resolve(parsed.path)
    if abs then
      local win = target_window(notes_win)
      vim.api.nvim_win_call(win, function()
        vim.cmd("edit " .. vim.fn.fnameescape(abs))
        pcall(vim.api.nvim_win_set_cursor, 0, { parsed.from or 1, 0 })
        vim.cmd("normal! zz")
      end)
    end
  end

  -- restore focus to the notes window and select the reference line
  vim.api.nvim_set_current_win(notes_win)
  vim.cmd("normal! V")
end

-- Buffer-local keymaps active only inside the notes buffer.
local function set_buffer_keymaps(buf)
  local function map(spec, fn)
    vim.keymap.set(spec.mode, spec.shortcut, fn, { buffer = buf, silent = true, desc = spec.desc })
  end
  map(keybindings.notes.jump, function()
    M.jump()
  end)
  map(keybindings.notes.next, function()
    M.goto_ref(1)
  end)
  map(keybindings.notes.prev, function()
    M.goto_ref(-1)
  end)
end

-- Create the notes buffer once and reuse it afterwards.
local function ensure_buffer()
  if M.bufnr and vim.api.nvim_buf_is_valid(M.bufnr) then
    return M.bufnr
  end

  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, NAME)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile" -- never auto-writes; ":w <path>" still works
  vim.bo[buf].bufhidden = "hide" -- survive closing its window
  vim.bo[buf].swapfile = false

  vim.b[buf].copilot_enabled = true

  set_buffer_keymaps(buf)
  M.bufnr = buf
  return buf
end

-- Return a window already showing the notes buffer, or open one in a vertical
-- split on the right.
local function get_or_open_window(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end

  vim.cmd("botright vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_width(win, math.max(40, math.floor(vim.o.columns * 0.35)))
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].wrap = true
  return win
end

-- Whether the buffer already has any real content.
local function has_content(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return #lines > 1 or (lines[1] ~= nil and lines[1] ~= "")
end

-- Append an entry (its body lines already ending with a blank note line) and
-- drop the cursor on that trailing blank line in insert mode.
local function append_lines(body)
  local buf = ensure_buffer()
  local win = get_or_open_window(buf)

  if has_content(buf) then
    local block = { "" } -- blank line separating entries into paragraphs
    local sep = M.config.separator
    if sep and sep ~= "" then
      table.insert(block, sep)
      table.insert(block, "")
    end
    vim.list_extend(block, body)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, block)
  else
    -- overwrite the lone empty line a fresh buffer starts with
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, body)
  end

  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { last, 0 })
  -- Defer to the next loop tick so a mode change from the triggering mapping
  -- (e.g. leaving visual mode) is fully processed before we enter insert, then
  -- re-assert focus on the notes window and start insert on the note line.
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      vim.cmd("startinsert")
    end
  end)
end

-- Append a reference entry: the reference line followed by a note line.
local function append_entry(ref)
  append_lines({ ref, "" })
end

-- Append a code snippet entry: an optional reference line, a fenced block
-- (tagged with the source filetype), and a note line.
local function append_snippet(lines, ft, ref)
  local body = {}
  if ref then
    table.insert(body, ref)
  end
  table.insert(body, "```" .. (ft or ""))
  vim.list_extend(body, lines)
  table.insert(body, "```")
  table.insert(body, "")
  append_lines(body)
end

-- Guard against operating on the source location while focused in the notes buffer.
local function in_notes_buffer()
  if M.bufnr and vim.api.nvim_get_current_buf() == M.bufnr then
    vim.notify("Already in the code-notes buffer", vim.log.levels.WARN)
    return true
  end
  return false
end

-- Add a note for the current line/selection.
function M.add()
  if in_notes_buffer() then
    return
  end
  append_entry(reference.line_ref()) -- computed while still on the source window
end

-- Add a note for the whole current file (no line reference).
function M.add_file()
  if in_notes_buffer() then
    return
  end
  append_entry(reference.relative_path())
end

-- Add the current line/selection as a code snippet (instead of a reference).
function M.add_snippet()
  if in_notes_buffer() then
    return
  end

  local ft = vim.bo.filetype
  local from, to
  -- mode() still reports visual here (Lua function rhs runs like <Cmd>).
  if vim.fn.mode():match("[vV\22]") then
    from, to = vim.fn.line("v"), vim.fn.line(".")
    if from > to then
      from, to = to, from
    end
    -- "x" flag leaves visual mode synchronously so the later startinsert sticks.
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  else
    from, to = vim.fn.line("."), vim.fn.line(".")
  end

  local lines = vim.api.nvim_buf_get_lines(0, from - 1, to, false)
  local ref = M.config.snippet_include_ref and reference.format(from, to) or nil
  append_snippet(lines, ft, ref)
end

-- Open/focus the notes window without adding an entry.
function M.open()
  local buf = ensure_buffer()
  local win = get_or_open_window(buf)
  vim.api.nvim_set_current_win(win)
end

-- Copy the whole notes buffer to the system clipboard.
function M.copy()
  if not (M.bufnr and vim.api.nvim_buf_is_valid(M.bufnr)) then
    vim.notify("No code notes yet", vim.log.levels.WARN)
    return
  end
  local lines = vim.api.nvim_buf_get_lines(M.bufnr, 0, -1, false)
  vim.fn.setreg("+", table.concat(lines, "\n"))
  vim.notify(string.format("Copied %d lines of notes", #lines), vim.log.levels.INFO)
end

-- Clear all notes.
function M.clear()
  if M.bufnr and vim.api.nvim_buf_is_valid(M.bufnr) then
    vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, {})
    vim.notify("Code notes cleared", vim.log.levels.INFO)
  end
end

return M
