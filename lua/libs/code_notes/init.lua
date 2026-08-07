-- Scratch "code notes" buffer: collect references to file locations together
-- with free-form notes, then copy/save the result (e.g. to hand to an AI agent).
-- Supports jumping back to a reference (<CR>) and cycling between references
-- (<Tab>/<S-Tab>) from inside the notes buffer.
local reference = require("libs.code_notes.reference")
local keybindings = require("keybindings")

local M = {}

---@type integer|nil Buffer number of the persistent notes buffer (nil until first use).
M.bufnr = nil
---@type table<string, integer> Buffers keyed by their project root.
M.buffers = {}
---@type string|nil Project root currently shown by M.bufnr.
M.root = nil

---@alias CodeNotes.Formatter fun(ref: string): string

---@class CodeNotes.Config
---@field separator? string Divider between entries ("" = blank line only). Used in block style.
---@field snippet_include_ref? boolean Prefix code snippets with their file reference.
---@field format_ref? CodeNotes.Formatter|nil Function to format a reference before insertion.
---   Place `{cursor}` in the returned string to position the cursor there.
---@field style? "block"|"list" Entry layout. "block" = blank lines + separator. "list" = compact lines.
---@field storage_dir? string Directory for per-project notes files.

---@type CodeNotes.Config
M.config = {
  separator = "---",
  snippet_include_ref = true,
  format_ref = nil,
  style = "block",
  storage_dir = vim.fn.stdpath("state") .. "/code-notes",
}

---@class CodeNotes.Format
---@field plain CodeNotes.Formatter Plain reference, cursor on next line.
---@field backtick CodeNotes.Formatter Wrap in backticks: `path#L10`
---@field link CodeNotes.Formatter Markdown link: [cursor](path#L10)
---@field link_with fun(label: string): CodeNotes.Formatter Markdown link with label: [label](path#L10)
---@field link_list CodeNotes.Formatter Markdown list item: - [cursor](path#L10)
---@field obsidian CodeNotes.Formatter Obsidian wikilink: [[cursor]](path#L10)
---@field obsidian_alias fun(alias: string): CodeNotes.Formatter Obsidian wikilink with alias: [[path#L10|alias]]

---@type CodeNotes.Format
M.format = {
  plain = function(ref) return ref end,
  backtick = function(ref) return "`" .. ref .. "`" end,
  link = function(ref) return "[{cursor}](" .. ref .. ")" end,
  link_with = function(label)
    return function(ref) return "[" .. label .. "](" .. ref .. ")" end
  end,
  link_list = function(ref) return "- [{cursor}](" .. ref .. ")" end,
  obsidian = function(ref) return "[[{cursor}]](" .. ref .. ")" end,
  obsidian_alias = function(alias)
    return function(ref) return "[[" .. ref .. "|" .. alias .. "]]" end
  end,
}

--- Apply user options on top of defaults.
---@param opts? CodeNotes.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Project root used to resolve the relative references back to absolute paths:
-- the git top-level of cwd, falling back to cwd itself.
local function project_root()
  local dot_git = vim.fs.find(".git", { upward = true, path = vim.fn.getcwd() })[1]
  if dot_git then
    return vim.fs.dirname(dot_git)
  end
  return vim.fn.getcwd()
end

local function notes_path(root)
  local id = vim.fn.sha256(root)
  return M.config.storage_dir .. "/" .. id .. ".md"
end

local function buffer_name(root)
  local project = vim.fs.basename(root)
  if project == "" then
    project = root
  end
  return "Code Notes [" .. project .. "]"
end

-- Whether the buffer already has any real content.
local function has_content(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return #lines > 1 or (lines[1] ~= nil and lines[1] ~= "")
end

local function read_project_notes(root, buf)
  local path = notes_path(root)
  if vim.fn.filereadable(path) == 1 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(path))
  end
  vim.bo[buf].modified = false
end

local function save_buffer(buf, root)
  vim.fn.mkdir(M.config.storage_dir, "p")
  local path = notes_path(root)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if vim.fn.writefile(lines, path) ~= 0 then
    vim.notify("Could not save code notes: " .. path, vim.log.levels.ERROR)
    return false
  end
  vim.bo[buf].modified = false
  vim.notify("Code notes saved for " .. root, vim.log.levels.INFO)
  return true
end

-- Ask before losing edits. The native confirm() keeps this usable from close
-- commands, where an asynchronous UI selector cannot pause the operation.
local function confirm_discard(buf, root)
  if not has_content(buf) or not vim.bo[buf].modified then
    return true
  end

  local choice = vim.fn.confirm(
    "Unsaved changes in:\n"
      .. buffer_name(root)
      .. "\n\nSave these notes before closing?",
    "&Save\n&Discard\n&Cancel",
    1,
    "Code Notes"
  )
  if choice == 1 then
    return save_buffer(buf, root)
  elseif choice == 2 then
    vim.bo[buf].modified = false
    return true
  end
  return false
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

local ref_parser = require("libs.code_notes.ref_parser")
local ns = vim.api.nvim_create_namespace("code_notes.preview")

-- Range previews are extmarks, not Vim's transient visual mode. Remove them
-- as soon as the user enters the referenced window so they cannot outlive the
-- preview or overlap a new visual selection.
vim.api.nvim_create_autocmd("WinEnter", {
  group = vim.api.nvim_create_augroup("code_notes_preview", { clear = true }),
  callback = function(args)
    vim.api.nvim_buf_clear_namespace(args.buf, ns, 0, -1)
  end,
})

-- { line, col } pairs (1-based line, 0-based col) of every reference in the
-- notes buffer.
local function ref_lines(buf)
  local out = {}
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local _, start = ref_parser.parse_ref(line, resolve)
    if start ~= nil then
      table.insert(out, { line = i, col = start })
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

--- Jump to the reference on the current notes line in the adjacent window.
function M.jump()
  local notes_win = vim.api.nvim_get_current_win()
  local parsed = ref_parser.parse_ref(vim.api.nvim_get_current_line(), resolve)
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
  vim.api.nvim_buf_clear_namespace(vim.api.nvim_get_current_buf(), ns, 0, -1)

  local from = parsed.from or 1
  if parsed.to and parsed.to > from then
    -- land on the range with it selected linewise
    vim.cmd(string.format("normal! %dGV%dGzz", from, parsed.to))
  else
    vim.api.nvim_win_set_cursor(win, { from, 0 })
    vim.cmd("normal! zz")
  end
end

--- Move to and preview the next/previous reference.
---@param dir 1|-1 Direction: 1 = next, -1 = previous.
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
    for _, r in ipairs(refs) do
      if r.line > cur then
        target = r
        break
      end
    end
    target = target or refs[1] -- wrap around
  else
    for i = #refs, 1, -1 do
      if refs[i].line < cur then
        target = refs[i]
        break
      end
    end
    target = target or refs[#refs] -- wrap around
  end

  vim.api.nvim_win_set_cursor(notes_win, { target.line, target.col })

  -- Preview the referenced file in the adjacent window, keeping focus here so
  -- the user can keep cycling; <CR> is what actually moves the cursor there.
  local parsed = ref_parser.parse_ref(vim.api.nvim_buf_get_lines(buf, target.line - 1, target.line, false)[1], resolve)
  if parsed then
    local abs = resolve(parsed.path)
    if abs then
      local win = target_window(notes_win)
      vim.api.nvim_win_call(win, function()
        vim.cmd("edit " .. vim.fn.fnameescape(abs))
        local from = parsed.from or 1
        pcall(vim.api.nvim_win_set_cursor, 0, { from, 0 })
        vim.cmd("normal! zz")
        -- Highlight the full range with a persistent extmark
        local target_buf = vim.api.nvim_win_get_buf(win)
        vim.api.nvim_buf_clear_namespace(target_buf, ns, 0, -1)
        if parsed.to and parsed.to > from then
          vim.highlight.range(target_buf, ns, "Visual", { from - 1, 0 }, { parsed.to, 0 }, { inclusive = false })
        end
      end)
    end
  end

  -- restore focus to the notes window and select just the reference content
  vim.api.nvim_set_current_win(notes_win)
  local _parsed, start, end_col =
    ref_parser.parse_ref(vim.api.nvim_buf_get_lines(buf, target.line - 1, target.line, false)[1], resolve)
  if _parsed and start and end_col then
    vim.api.nvim_win_set_cursor(notes_win, { target.line, start })
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(notes_win, { target.line, end_col })
  end
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
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = buf, silent = true, desc = "Close code notes safely" })
  vim.keymap.set("n", "<leader>bd", function()
    M.close()
  end, { buffer = buf, silent = true, desc = "Close code notes safely" })
  for _, shortcut in ipairs({ "<C-w>q", "<C-w>c" }) do
    vim.keymap.set("n", shortcut, function()
      M.close()
    end, { buffer = buf, silent = true, desc = "Close code notes safely" })
  end
end

-- Create one notes buffer per project root and reuse it afterwards.
local function ensure_buffer(root)
  local existing = M.buffers[root]
  if existing and vim.api.nvim_buf_is_valid(existing) then
    M.bufnr = existing
    M.root = root
    return existing
  end

  local buf = vim.api.nvim_create_buf(true, false)
  -- Keep the name URI-like so Neovim does not resolve it relative to cwd.
  vim.api.nvim_buf_set_name(buf, "code-notes://" .. buffer_name(root))
  -- This is markdown content, but not a real markdown file. A dedicated
  -- filetype keeps markdown LSP clients (notably Marksman) away from the
  -- synthetic code-notes:// URI.
  vim.bo[buf].filetype = "code_notes"
  vim.bo[buf].syntax = "markdown"
  vim.bo[buf].buftype = "acwrite" -- track edits without writing the URI name
  vim.bo[buf].bufhidden = "hide" -- survive closing its window
  vim.bo[buf].swapfile = false

  vim.b[buf].copilot_enabled = true

  set_buffer_keymaps(buf)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      save_buffer(buf, root)
    end,
  })
  read_project_notes(root, buf)
  vim.b[buf].code_notes_root = root
  vim.b[buf].code_notes_path = notes_path(root)
  M.buffers[root] = buf
  M.bufnr = buf
  M.root = root
  return buf
end

-- Switch the active notes buffer, preserving edits in the previous project.
local function ensure_current_project()
  local root = project_root()
  if M.root and M.root ~= root and M.bufnr and vim.api.nvim_buf_is_valid(M.bufnr) then
    if not confirm_discard(M.bufnr, M.root) then
      return nil
    end
  end
  return ensure_buffer(root)
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
  vim.api.nvim_win_set_config(win, { width = math.max(40, math.floor(vim.o.columns * 0.35)) })
  vim.wo[win].spell = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].wrap = true
  return win
end

-- Insert lines into the notes buffer and position the cursor at the first
-- `{cursor}` marker (removing it), or on the last line in insert mode.
local function append_lines(lines)
  local buf = ensure_current_project()
  if not buf then
    return
  end
  local win = get_or_open_window(buf)

  -- Scan for {cursor} marker before inserting
  local cursor_line, cursor_col
  for i, line in ipairs(lines) do
    local s = line:find("{cursor}", 1, true)
    if s then
      cursor_line = i
      cursor_col = s - 1 -- 1-based Lua index → 0-based nvim column (after removal)
      lines[i] = line:sub(1, s - 1) .. line:sub(s + 8)
      break
    end
  end

  if has_content(buf) then
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_set_current_win(win)

  if not cursor_line then
    vim.api.nvim_win_set_cursor(win, { last, 0 })
  end

  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      if cursor_line then
        local line_in_buf = last - #lines + cursor_line
        vim.api.nvim_win_set_cursor(win, { line_in_buf, cursor_col })
      end
      vim.cmd("startinsert")
    end
  end)
end

-- Append a reference entry. Builds the full block depending on config.style.
local function append_entry(ref)
  local fmt = M.config.format_ref
  local line = fmt and fmt(ref) or ref
  local style = M.config.style

  if style == "list" then
    append_lines({ line })
  else
    -- block style: blank line + optional separator + reference + note line
    local entry = { "", line, "" }
    local sep = M.config.separator
    if sep and sep ~= "" then
      table.insert(entry, 2, sep) -- insert separator after blank line
    end
    append_lines(entry)
  end
end

-- Append a code snippet entry: optional reference, fenced code block, note line.
local function append_snippet(lines, ft, ref)
  local body = {}
  if ref then
    table.insert(body, ref)
  end
  table.insert(body, "```" .. (ft or ""))
  vim.list_extend(body, lines)
  table.insert(body, "```")

  local style = M.config.style
  if style == "list" then
    table.insert(body, "")
    append_lines(body)
  else
    local entry = { "", unpack(body) }
    table.insert(entry, "")  -- trailing note line
    local sep = M.config.separator
    if sep and sep ~= "" then
      table.insert(entry, 2, sep)
    end
    append_lines(entry)
  end
end

-- Guard against operating on the source location while focused in the notes buffer.
local function in_notes_buffer()
  if M.bufnr and vim.api.nvim_get_current_buf() == M.bufnr then
    vim.notify("Already in the code-notes buffer", vim.log.levels.WARN)
    return true
  end
  return false
end

--- Add a note for the current line/selection.
function M.add()
  if in_notes_buffer() then
    return
  end
  append_entry(reference.line_ref()) -- computed while still on the source window
end

--- Add a note for the whole current file (no line reference).
function M.add_file()
  if in_notes_buffer() then
    return
  end
  append_entry(reference.relative_path())
end

--- Add the current line/selection as a code snippet.
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

--- Open/focus the notes window without adding an entry.
function M.open()
  local buf = ensure_current_project()
  if not buf then
    return
  end
  local win = get_or_open_window(buf)
  vim.api.nvim_set_current_win(win)
end

--- Save notes for the current project.
function M.save()
  local buf = ensure_current_project()
  if buf then
    save_buffer(buf, M.root)
  end
end

--- Reload notes for the current project from disk.
function M.load()
  local buf = ensure_current_project()
  if not buf or not confirm_discard(buf, M.root) then
    return
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  read_project_notes(M.root, buf)
  vim.notify("Code notes loaded for " .. M.root, vim.log.levels.INFO)
end

--- Close the current notes window without silently losing edits.
function M.close()
  local buf = M.bufnr
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  if not confirm_discard(buf, M.root) then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) == buf then
    vim.api.nvim_win_close(win, false)
  end
end

--- Copy the whole notes buffer to the system clipboard.
function M.copy()
  local buf = ensure_current_project()
  if not buf or not has_content(buf) then
    vim.notify("No code notes yet", vim.log.levels.WARN)
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.fn.setreg("+", table.concat(lines, "\n"))
  vim.notify(string.format("Copied %d lines of notes", #lines), vim.log.levels.INFO)
end

--- Clear all notes.
function M.clear()
  local buf = ensure_current_project()
  if buf and confirm_discard(buf, M.root) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.notify("Code notes cleared", vim.log.levels.INFO)
  end
end

return M
