return {
  -- Statusline:
  --  +-------------------------------------------------+
  --  | A | B | C                             X | Y | Z |
  --  +-------------------------------------------------+
  --
  -- LazyVim defaults:
  -- * A: mode (n, i, <C-v>, V,...)
  -- * B: git branch
  -- * C: root_dir | diagnostics | filetype icon + file path
  -- * X: last command | noice.api.status.mode??? | DAP (bug icon) | LazyVim updates (packages) | git diff
  -- * Y: progress [%] | location (line:column)
  -- * Z: clocks
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local icons = require("lazyvim.config").icons

      local base_winbar = {
        lualine_a = {
          {
            "filename",
            path = 0,
          },
        },

        -- show path to the file
        lualine_c = {
          {
            "filename",
            file_status = false,
            path = 2,

            -- Shortens path to leave 5 spaces in the window
            -- for other components. (terrible name)
            shorting_target = 5,
            fmt = function(path)
              local root_path = LazyVim.root.cwd()

              -- INFO: handle the worktree dir as the project root
              local git_root = vim.fn.FugitiveWorkTree()

              if git_root ~= "" then
                root_path = git_root
              end

              return vim.fn.fnamemodify(path:sub(#root_path + 2), ":h") .. "/"
            end,
          },
        },

        lualine_x = {
          {
            "diagnostics",
            symbols = {
              error = icons.diagnostics.Error,
              warn = icons.diagnostics.Warn,
              info = icons.diagnostics.Info,
              hint = icons.diagnostics.Hint,
            },
          },
        },

        -- show harpoon index
        lualine_y = {

          -- {
          --   "filename",
          --   file_status = false,
          --   path = 2,
          --   -- fmt = function(path)
          --   --   local Marked = require("harpoon.mark")
          --   --   local success, index = pcall(Marked.get_index_of, path)
          --   --   if success and index and index > 0 then
          --   --     return string.format("%d*", index) -- <-- Add your favorite harpoon like arrow here
          --   --   end
          --   -- end,
          -- },
          -- Git worktree name 󰊢 | Git-project folder name  | CWD folder name 
          -- {
          --   function()
          --     local cwd_root = LazyVim.root.get()
          --     local git_root = vim.fs.find(".git", { path = cwd_root, upward = true })[1]
          --     local worktree_name, worktree_match = vim.fn.FugitiveGitDir():gsub(".*worktrees/", "")
          --
          --     if worktree_match == 1 then
          --       return worktree_name .. " 󰊢"
          --     end
          --
          --     if git_root then
          --       return vim.fn.fnamemodify(git_root, ":h:t") .. " "
          --     end
          --
          --     return vim.fn.fnamemodify(cwd_root, ":t") .. " "
          --   end,
          -- },
        },
      }

      opts.winbar = vim.deepcopy(base_winbar)
      opts.winbar.lualine_c[1].color = "StatusLineNC"
      opts.inactive_winbar = vim.deepcopy(base_winbar)

      opts.options.disabled_filetypes.winbar = {
        "snacks_picker_list",
        "snacks_layout_box",
        "quickfix",
        "qf",
        "prompt",
        "trouble",
        "snacks_dashboard",
        "dashboard",
        "alpha",
        "starter",
        "noice",
        "git",
        "nofile",
        "fugitiveblame",
        "DiffviewFiles",
      }

      -- simplify global statusline
      opts.sections.lualine_c = {
        LazyVim.lualine.root_dir(),
        { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
        { LazyVim.lualine.pretty_path() },
      }

      table.insert(opts.sections.lualine_y, "fileformat")

      return opts
    end,
  },
}
