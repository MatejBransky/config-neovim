local keybindings = require("keybindings")

-- NOTE: I don't know why but copilot suggestion keymap does not work if
-- copilot-language-server is installed via mason.
return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    dependencies = {
      "copilotlsp-nvim/copilot-lsp",
    },
    event = "BufReadPost",
    opts = {
      panel = {
        auto_refresh = true,
      },
      suggestion = {
        auto_trigger = true,
        keymap = {
          accept = keybindings.ai.accept.shortcut,
          accept_word = keybindings.ai.accept_word.shortcut,
          accept_line = keybindings.ai.accept_line.shortcut,
          next = keybindings.ai.next.shortcut,
          prev = keybindings.ai.prev.shortcut,
          dismiss = keybindings.ai.dismiss.shortcut,
        },
      },
    },
  },

  -- copilot-language-server
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- copilot.lua only works with its own copilot lsp server
        copilot = { enabled = false },
      },
    },
  },

  {
    "blink.cmp",
    opts = {
      completion = {
        ghost_text = {
          -- reserve ghost test to ai copilot suggestions
          show_with_menu = false,
        },
      },
    },
  },

  -- {
  --   "NickvanDyke/opencode.nvim",
  --   dependencies = {
  --     -- Recommended for `ask()` and `select()`.
  --     -- Required for `snacks` provider.
  --     ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
  --     { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
  --   },
  --   config = function()
  --     ---@type opencode.Opts
  --     vim.g.opencode_opts = {
  --       -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
  --     }
  --
  --     -- Required for `opts.events.reload`.
  --     vim.o.autoread = true
  --
  --     -- Recommended/example keymaps.
  --     vim.keymap.set({ "n", "x" }, "<C-a>", function()
  --       require("opencode").ask("@this: ", { submit = true })
  --     end, { desc = "Ask opencode" })
  --
  --     vim.keymap.set({ "n", "x" }, "<C-x>", function()
  --       require("opencode").select()
  --     end, { desc = "Execute opencode action…" })
  --
  --     vim.keymap.set({ "n", "t" }, "<C-.>", function()
  --       require("opencode").toggle()
  --     end, { desc = "Toggle opencode" })
  --
  --     vim.keymap.set({ "n", "x" }, "go", function()
  --       return require("opencode").operator("@this ")
  --     end, { expr = true, desc = "Add range to opencode" })
  --
  --     vim.keymap.set("n", "goo", function()
  --       return require("opencode").operator("@this ") .. "_"
  --     end, { expr = true, desc = "Add line to opencode" })
  --
  --     vim.keymap.set("n", "<S-C-u>", function()
  --       require("opencode").command("session.half.page.up")
  --     end, { desc = "opencode half page up" })
  --
  --     vim.keymap.set("n", "<S-C-d>", function()
  --       require("opencode").command("session.half.page.down")
  --     end, { desc = "opencode half page down" })
  --
  --     -- You may want these if you stick with the opinionated "<C-a>" and "<C-x>" above — otherwise consider "<leader>o".
  --     vim.keymap.set("n", "+", "<C-a>", { desc = "Increment", noremap = true })
  --     vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement", noremap = true })
  --   end,
  -- },
}
