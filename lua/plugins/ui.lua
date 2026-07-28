local Snacks = require("snacks")

local colorscheme_sync = require("libs.colorscheme_sync")

local gitActions = {
  actions = {
    ["open_file"] = function(picker)
      local currentCommit = picker:current().commit
      picker:close()
      vim.cmd("Gitsigns show " .. currentCommit)
    end,
    ["open_diffview"] = function(picker)
      local currentCommit = picker:current().commit
      picker:close()
      vim.cmd("DiffviewOpen " .. currentCommit .. "^.." .. currentCommit)
    end,
  },
  win = {
    input = {
      keys = {
        ["<CR>"] = {
          "open_file",
          desc = "Open File",
          mode = { "n", "i" },
        },
        ["<M-g>"] = {
          "open_diffview",
          desc = "Open Diffview (commit)",
          mode = { "n", "i" },
        },
      },
    },
  },
}

local layout_dropdown = {
  layout = {
    -- Base on `dropdown` layout
    -- https://github.com/folke/snacks.nvim/blob/bc0630e43be5699bb94dadc302c0d21615421d93/lua/snacks/picker/config/layouts.lua#L106-L125
    layout = {
      backdrop = false,
      width = 0.8,
      min_width = 80,
      height = 0.8,
      border = "none",
      box = "vertical",
      {
        box = "vertical",
        border = "rounded",
        title = "{title} {live} {flags}",
        title_pos = "center",
        { win = "input", height = 1, border = "bottom" },
        { win = "list", border = "none" },
      },
      -- NOTE: Swapped
      { win = "preview", title = "{preview}", height = 0.6, border = "rounded" },
    },
  },
}

return {
  -- disable tabs
  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },

  -- Scrollbar
  {
    "petertriho/nvim-scrollbar",
    event = "BufReadPost",
    opts = {
      excluded_filetypes = { "prompt", "TelescopePrompt", "noice", "notify", "neo-tree" },
      handlers = {
        -- cursor = false,
      },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = function()
      require("scrollbar.handlers.gitsigns").setup()
    end,
  },

  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      picker = {
        -- debug = {
        --   scores = true,
        -- },
        formatters = {
          file = {
            filename_first = true, -- display filename before the file path
            truncate = 10000,
          },
        },
        sources = {
          buffers = {
            layout = { preset = "select" },
            current = false,
          },
          grep = layout_dropdown,
          lsp_references = layout_dropdown,
          smart = {
            hidden = true,
            -- multi = { "buffers", "files" },
            transform = function(item, ctx)
              if require("snacks.picker.transform").unique_file(item, ctx) == false then
                return false
              end
              item.buf_lastused = item.info and item.info.lastused or 0
            end,
            sort = {
              fields = { "buf_lastused:desc", "score:desc", "#text", "idx" },
            },
            -- sort = { fields = { "source_id" } },
            -- matcher = { frecency = false },
            filter = {
              cwd = true,
            },
          },
          explorer = {
            hidden = true,
            win = {
              input = {
                keys = {
                  ["<c-c>"] = {
                    "cancel",
                    mode = { "n", "i", "x" },
                  },
                },
              },
              list = {
                keys = {
                  ["<c-g>"] = {
                    "tcd",
                    mode = { "n", "i" },
                  },
                  ["<c-c>"] = {
                    "cancel",
                    mode = { "n", "i", "x" },
                  },
                },
              },
            },
          },
          git_log_file = gitActions,
          git_log = gitActions,
        },
        win = {
          input = {
            keys = {
              ["<c-c>"] = {
                "cancel",
                mode = { "n", "i", "x" },
              },
            },
          },
        },
        actions = {
          cycle_preview = function(picker)
            local layout_config = vim.deepcopy(picker.resolved_layout)

            if layout_config.preview == "main" or not picker.preview.win:valid() then
              return
            end

            local function find_preview(root) ---@param root snacks.layout.Box|snacks.layout.Win
              if root.win == "preview" then
                return root
              end
              if #root then
                for _, w in ipairs(root) do
                  local preview = find_preview(w)
                  if preview then
                    return preview
                  end
                end
              end
              return nil
            end

            local preview = find_preview(layout_config.layout)

            if not preview then
              return
            end

            local eval = function(s)
              return type(s) == "function" and s(preview.win) or s
            end
            --- @type number?, number?
            local width, height = eval(preview.width), eval(preview.height)

            if not width and not height then
              return
            end

            local cycle_sizes = { 0.1, 0.9 }
            local size_prop, size

            if height then
              size_prop, size = "height", height
            else
              size_prop, size = "width", width
            end

            picker.init_size = picker.init_size or size ---@diagnostic disable-line: inject-field
            table.insert(cycle_sizes, picker.init_size)
            table.sort(cycle_sizes)

            for i, s in ipairs(cycle_sizes) do
              if size == s then
                local smaller = cycle_sizes[i - 1] or cycle_sizes[#cycle_sizes]
                preview[size_prop] = smaller
                break
              end
            end

            for i, h in ipairs(layout_config.hidden) do
              if h == "preview" then
                table.remove(layout_config.hidden, i)
              end
            end

            picker:set_layout(layout_config)
          end,
        },
      },
      explorer = {
        replace_netrw = true,
      },
    },
    keys = {
      -- disable Github related keymaps
      { "<leader>gi", false },
      { "<leader>gI", false },
      { "<leader>gp", false },
      { "<leader>gP", false },
      { "<leader>gf", false },
      { "<leader>gd", false },

      {
        "<M-\\>",
        function()
          Snacks.explorer({ auto_close = true, layout = "default" })
        end,
        desc = "Show explorer",
      },
      {
        "<M-,>",
        function()
          Snacks.picker.smart({
            layout = "default",
          })
        end,
        desc = "Find files",
      },
      {
        "<C-p>",
        function()
          Snacks.picker.actions("cycle_preview")
        end,
        desc = "Cycle preview layout",
      },
    },
  },

  {
    "folke/flash.nvim",
    keys = {
      {
        "<c-space>",
        mode = { "n", "o", "x" },
        function()
          require("flash").treesitter({
            labels = "123456789",
            actions = {
              ["<c-space>"] = "next",
              ["<BS>"] = "prev",
            },
          })
        end,
        desc = "Treesitter Incremental Selection",
      },
    },
  },

  {
    "typicode/bg.nvim",
    lazy = false,
    config = function()
      colorscheme_sync.watch_theme_changes()
      colorscheme_sync.watch_config_changes()
    end,
  },
}
