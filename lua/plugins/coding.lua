-- "Faster coding with features such as snippets, autocompletion, and more."

return {
  -- text-case conversion
  {
    "johmsalas/text-case.nvim",
    config = function()
      require("textcase").setup({})
    end,
    keys = {
      "ga", -- Default invocation prefix
    },
    -- If you want to use the interactive feature of the `Subs` command right away, text-case.nvim
    -- has to be loaded on startup. Otherwise, the interactive feature of the `Subs` will only be
    -- available after the first executing of it or after a keymap of text-case.nvim has been used.
    lazy = false,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "css",
        "scss",
        "styled",
      },
    },
  },

  {
    "eero-lehtinen/oklch-color-picker.nvim",
    event = "VeryLazy",
    version = "*",
    keys = {
      -- One handed keymap recommended, you will be using the mouse
      {
        "<leader>v",
        function()
          require("oklch-color-picker").pick_under_cursor()
        end,
        desc = "Color pick under cursor",
      },
    },
    ---@type oklch.Opts
    opts = {
      highlight = {
        style = "virtual_eol",
        virtual_text = "[■]",
      },
    },
  },

  {
    "ThePrimeagen/harpoon",
    keys = {
      {
        "<leader>h",
        false,
      },
      {
        "<M-h>",
        function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = "Harpoon Quick Menu",
      },
    },
  },
}
