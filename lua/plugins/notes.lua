local keybindings = require("keybindings")

-- Local "code notes" plugin: a scratch buffer that collects references to file
-- locations (path#L10 / path#L45-L67) together with free-form notes, so they
-- can be copied/saved and reused elsewhere (e.g. handed to an AI agent).
-- Implementation lives in lua/libs/code_notes/.
return {
  {
    "nvim-mini/mini.test",
    build = false,
    dependencies = { "nvim-mini/mini.nvim" },
    config = function()
      require("mini.test").setup()
    end,
  },
  {
    "code-notes",
    dir = vim.fn.stdpath("config"),
    lazy = true,
    dependencies = { "nvim-lua/plenary.nvim" },
    -- Config passed to require("libs.code_notes").setup().
    opts = {
      -- Divider inserted between note entries. "" = only a blank line.
      separator = "---",
      -- Prefix code snippets with their file reference (path#L3-L4), which also
      -- lets <Tab>/<CR> navigate/jump to snippets like plain references.
      snippet_include_ref = true,
      format_ref = require("libs.code_notes").format.link_list,
      style = "list",
    },
    keys = {
      {
        keybindings.notes.add.shortcut,
        function()
          require("libs.code_notes").add()
        end,
        mode = keybindings.notes.add.mode,
        desc = keybindings.notes.add.desc,
      },
      {
        keybindings.notes.addFile.shortcut,
        function()
          require("libs.code_notes").add_file()
        end,
        mode = keybindings.notes.addFile.mode,
        desc = keybindings.notes.addFile.desc,
      },
      {
        keybindings.notes.addSnippet.shortcut,
        function()
          require("libs.code_notes").add_snippet()
        end,
        mode = keybindings.notes.addSnippet.mode,
        desc = keybindings.notes.addSnippet.desc,
      },
      {
        keybindings.notes.open.shortcut,
        function()
          require("libs.code_notes").open()
        end,
        mode = keybindings.notes.open.mode,
        desc = keybindings.notes.open.desc,
      },
      {
        keybindings.notes.copy.shortcut,
        function()
          require("libs.code_notes").copy()
        end,
        mode = keybindings.notes.copy.mode,
        desc = keybindings.notes.copy.desc,
      },
    },
    cmd = { "CodeNotesClear" },
    config = function(_, opts)
      require("libs.code_notes").setup(opts)
      vim.api.nvim_create_user_command("CodeNotesClear", function()
        require("libs.code_notes").clear()
      end, { desc = "Clear the code notes buffer" })
    end,
  },
}
