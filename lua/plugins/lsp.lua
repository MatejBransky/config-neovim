local keybindings = require("keybindings")

return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      vim.keymap.set(
        keybindings.lsp.log.mode,
        keybindings.lsp.log.shortcut,
        "<Cmd>log lsp<CR>",
        { desc = keybindings.lsp.log.desc }
      )
      vim.keymap.set(
        keybindings.lsp.log.mode,
        keybindings.lsp.info.shortcut,
        "<Cmd>checkhealth vim.lsp<CR>",
        { desc = keybindings.lsp.info.desc }
      )
      vim.keymap.set(
        keybindings.lsp.log.mode,
        keybindings.lsp.restart.shortcut,
        "<Cmd>lsp restart<CR>",
        { desc = keybindings.lsp.restart.desc }
      )

      vim.keymap.set(
        keybindings.lsp.showDiagWindow.mode,
        keybindings.lsp.showDiagWindow.shortcut,
        vim.diagnostic.open_float,
        { desc = keybindings.lsp.showDiagWindow.desc }
      )
    end,
    ---@class PluginLspOpts
    opts = {
      inlay_hints = {
        enabled = false,
      },
      diagnostics = { virtual_text = false },
      -- LSP Server Settings
      ---@type lspconfig.options
      servers = {
        ["*"] = {
          keys = {
            { "K", false },
            { keybindings.lsp.hoverInfo.shortcut, vim.lsp.buf.hover, desc = keybindings.lsp.hoverInfo.desc },
            {
              keybindings.lsp.prevRef.shortcut,
              function()
                Snacks.words.jump(-vim.v.count1)
              end,
              has = "documentHighlight",
              desc = keybindings.lsp.prevRef.desc,
            },
            {
              keybindings.lsp.nextRef.shortcut,
              function()
                Snacks.words.jump(vim.v_count1)
              end,
              has = "documentHighlight",
              desc = keybindings.lsp.nextRef.desc,
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              workspace = {
                library = {
                  vim.fn.expand("$VIMRUNTIME/lua"),
                  -- make accessible lua files from the pde/ folder
                  "~/.config/pde/",
                },
                checkThirdParty = false,
              },
            },
          },
        },
      },
    },
  },
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    opts = {
      preset = "powerline",
      options = {
        add_messages = {
          display_count = true,
        },
        multilines = {
          enabled = true,
        },
      },
    },
  },

  {
    "folke/lazydev.nvim",
    ft = "lua",
    dependencies = {
      {
        "DrKJeff16/wezterm-types",
        lazy = true,
        version = false, -- Get the latest version
      },
    },
    opts = {
      library = {
        -- Other library configs...
        { path = "wezterm-types", mods = { "wezterm" } },
      },
    },
  },
}
