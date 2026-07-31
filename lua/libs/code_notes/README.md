# Code Notes

Scratch buffer plugin for collecting file references and notes. Useful for keeping track of relevant code locations, then copying the result (e.g. to hand to an AI agent).

## How it works

A persistent markdown buffer (`code-notes.md`) opens in a vertical split on the right. Each entry consists of a file reference followed by a free-form note. References are clickable — jump to the source with `<CR>`, cycle between them with `<Tab>`/`<S-Tab>`.

### Reference formats

References can appear inline in text, wrapped in backticks, or as markdown links:

| Format | Example |
|--------|---------|
| Bare path | `src/main.lua` |
| Path + line | `src/main.lua#L10` |
| Path + range | `src/main.lua#L10-L20` |
| Backtick wrapped | `` `src/main.lua#L10` `` |
| Markdown link | `[label](src/main.lua#L10)` |

References are resolved relative to the git root (or cwd if not in a repo).

## Commands

| Command | Description |
|---------|-------------|
| `:CodeNotesClear` | Clear all notes |

## Keymaps

### Global (from any buffer)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>on` | n, v | Add line/selection reference to notes |
| `<leader>oF` | n | Add current file reference to notes |
| `<leader>oc` | n, v | Add line/selection as a code snippet |
| `<leader>oN` | n | Open/focus the notes window |
| `<leader>oy` | n | Copy all notes to clipboard |

### Buffer-local (inside the notes buffer)

| Key | Mode | Description |
|-----|------|-------------|
| `<CR>` | n, x | Jump to the reference under cursor |
| `<Tab>` | n, x | Select the next reference |
| `<S-Tab>` | n, x | Select the previous reference |

## Configuration

```lua
require("mini.test").setup() -- or through lazy.nvim opts
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `separator` | string | `"---"` | Divider between entries (block style). `""` = blank line only. |
| `snippet_include_ref` | boolean | `true` | Prefix code snippets with their file reference (`path#L3-L4`). |
| `format_ref` | function\|nil | `nil` | Formats reference before insertion. Place `{cursor}` for cursor position. |
| `style` | `"block"` \| `"list"` | `"block"` | `"block"` = blank lines + separator. `"list"` = compact lines, no separators. |

### Style: block vs list

**Block** (default) — each entry separated by blank lines + divider:
```
First note

---
Second note
```

**List** — compact bulleted list, no extra spacing:
```
- [First note](path#L1)
- [Second note](path#L2)
```

```lua
opts = {
  style = "list",
  format_ref = require("libs.code_notes").format.link_list,
}
```

### Format presets

```lua
local notes = require("libs.code_notes")

-- Available formatters:
notes.format.plain       -- path#L10            (cursor on next line)
notes.format.backtick    -- `path#L10`
notes.format.link        -- [cursor](path#L10)  (cursor inside [])
notes.format.link_with("viz") -- [viz](path#L10)
notes.format.link_list   -- - [cursor](path#L10)  (markdown list item)
notes.format.obsidian    -- [[cursor]](path#L10) (Obsidian wikilink with cursor)
notes.format.obsidian_alias("Main") -- [[path#L10|Main]] (Obsidian wikilink with alias)

-- Use in config:
opts = {
  format_ref = notes.format.backtick,
}
```

### Custom formatter

```lua
opts = {
  format_ref = function(ref)
    return "> " .. ref .. " {cursor}"  -- cursor placed after ref
  end,
}
```

### Full example

```lua
{
  "code-notes",
  dir = vim.fn.stdpath("config"),
  opts = {
    separator = "",
    snippet_include_ref = false,
    format_ref = require("libs.code_notes").format.link_list,
    style = "list",
  },
}
```
