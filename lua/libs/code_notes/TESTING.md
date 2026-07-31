# Tests

Tests for `libs/code_notes/ref_parser.lua` using [mini.test](https://github.com/nvim-mini/mini.test).

Documentation: https://nvim-mini.org/mini.nvim/TESTING

## Running tests

### From CLI

```sh
# All tests
nvim --headless -u NONE -l scripts/minitest.lua

# Specific file
TEST_FILE=tests/test_parse_ref.lua nvim --headless -u NONE -l scripts/minitest.lua

# Filter by name (Lua pattern)
TEST_FILTER="backtick" nvim --headless -u NONE -l scripts/minitest.lua

# Skip tests matching a pattern
TEST_FILTER_OUT="no ref" nvim --headless -u NONE -l scripts/minitest.lua
```

Recommended shell alias (add to `~/.zshrc`):

```sh
alias nvtest="nvim --headless -u NONE -l $HOME/.config/nvim/scripts/minitest.lua"
```

### From Neovim (interactive)

Open a test file (`tests/test_*.lua`) and run:

```vim
" Run entire current file
:lua MiniTest.run_file()

" Run test at cursor position (nearest case)
:lua MiniTest.run_at_location()
```

Both commands require the current buffer to be a test file. They won't work from a regular source file.

Or use keymaps (add to your config):

```lua
vim.keymap.set("n", "<leader>tf", "<cmd>lua MiniTest.run_file()<cr>", { desc = "Run test file" })
vim.keymap.set("n", "<leader>tn", "<cmd>lua MiniTest.run_at_location()<cr>", { desc = "Run nearest test" })
```

Results appear in a split buffer. Press `q` or `<Esc>` to close it.

See also: https://nvim-mini.org/mini.nvim/TESTING

## Writing tests

Test files live in `tests/` and must start with `test_`. They return a table created by `MiniTest.new_set()`.

```lua
local T = MiniTest.new_set()

T["group name"] = MiniTest.new_set()

T["group name"]["test case"] = function()
  MiniTest.expect.equality(1 + 1, 2)
end

return T
```

### Available expectations

- `MiniTest.expect.equality(left, right)` — assert `left == right`
- `MiniTest.expect.no_equality(left, right)` — assert `left ~= right`
- `MiniTest.expect.error(f, pattern)` — assert `f()` throws matching error
- `MiniTest.expect.no_error(f)` — assert `f()` doesn't throw

### Skip a test

```lua
T["skipped"] = function()
  MiniTest.skip("not implemented yet")
end
```

### Interactive usage

Inside Neovim with mini.test loaded:

```vim
" Run nearest test at cursor
:lua MiniTest.run_at_location()

" Run current file
:lua MiniTest.run_file()
```

Keymaps (if configured): `<LocalLeader>tn` runs nearest test.

## Test coverage

| Test file | Coverage |
|-----------|----------|
| `test_parse_ref.lua` | `parse_ref`: backtick, markdown link, bare ref, whole file, inline, ranges, no ref |
| `test_format_ref.lua` | `format_ref` presets, `{cursor}` marker, config assignment |
