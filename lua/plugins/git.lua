local keybindings = require("keybindings")

return {
  { "tpope/vim-rhubarb" }, -- github support for vim-fugitive
  {
    "tpope/vim-fugitive",
    config = function()
      local reference = require("libs.code_notes.reference")

      vim.keymap.set(keybindings.references.copyFilepath.mode, keybindings.references.copyFilepath.shortcut, function()
        vim.fn.setreg("*", reference.relative_path())
      end, { desc = keybindings.references.copyFilepath.desc, silent = true })

      vim.keymap.set(keybindings.references.copyLineRef.mode, keybindings.references.copyLineRef.shortcut, function()
        local ref = reference.line_ref()
        vim.fn.setreg("*", ref)
        vim.notify("Copied: " .. ref, vim.log.levels.INFO)
      end, { desc = keybindings.references.copyLineRef.desc, silent = true })

      vim.keymap.set(
        keybindings.references.openInBrowser.mode,
        keybindings.references.openInBrowser.shortcut,
        "<Cmd>GBrowse<CR>",
        { desc = keybindings.references.openInBrowser.desc }
      )

      vim.keymap.set(
        keybindings.references.copyFileLink.mode,
        keybindings.references.copyFileLink.shortcut,
        "<Cmd>GBrowse!<CR>",
        { desc = keybindings.references.copyFileLink.desc }
      )

      vim.keymap.set(
        keybindings.references.copyLineLink.mode,
        keybindings.references.copyLineLink.shortcut,
        "<Cmd>.GBrowse!<CR>",
        { desc = keybindings.references.copyLineLink.desc, silent = true }
      )

      vim.keymap.set(
        keybindings.git.fastForward.mode,
        keybindings.git.fastForward.shortcut,
        "<Cmd>G pull --ff-only<CR>",
        { desc = keybindings.git.fastForward.desc }
      )
    end,
  },
  {
    "sindrets/diffview.nvim",
    -- INFO: this allows me to open nvim in the diffview mode immediately (nvim -c DiffviewOpen)
    cmd = { "DiffviewOpen" },
    opts = {
      view = {
        merge_tool = {
          layout = "diff3_mixed",
        },
      },
      keymaps = {
        view = {
          {
            "n",
            "gf",
            function()
              local view = require("diffview.lib").get_current_view()
              if not view then
                vim.notify("No diffview open", vim.log.levels.WARN)
                return
              end

              local rev = view.left
              if not rev or not rev.commit then
                vim.notify("No commit revision found", vim.log.levels.WARN)
                return
              end

              local file = view.panel.cur_file
              if not file then
                vim.notify("No file selected", vim.log.levels.WARN)
                return
              end

              vim.cmd("tabnew")
              vim.cmd("keepalt Gedit " .. rev.commit .. ":" .. file.path)
            end,
            { desc = "Open file at commit revision via fugitive", silent = true },
          },
        },
        file_panel = {
          {
            "n",
            "gf",
            function()
              local view = require("diffview.lib").get_current_view()
              if not view then
                vim.notify("No diffview open", vim.log.levels.WARN)
                return
              end

              local rev = view.left
              if not rev or not rev.commit then
                vim.notify("No commit revision found", vim.log.levels.WARN)
                return
              end

              local file = view.panel:get_item_at_cursor()
              if not file or not file.path then
                vim.notify("No file selected", vim.log.levels.WARN)
                return
              end

              vim.cmd("tabnew")
              vim.cmd("keepalt Gedit " .. rev.commit .. ":" .. file.path)
            end,
            { desc = "Open file at commit revision via fugitive", silent = true },
          },
        },
        file_history_panel = {
          {
            "n",
            "gf",
            function()
              local view = require("diffview.lib").get_current_view()
              if not view then
                vim.notify("No diffview open", vim.log.levels.WARN)
                return
              end

              local entry = view.panel:get_log_entry_at_cursor()
              if not entry or not entry.commit then
                vim.notify("No commit selected", vim.log.levels.WARN)
                return
              end

              local hash = entry.commit.hash
              local file = entry.files[1]
              if not hash or not file then
                vim.notify("Cannot determine commit or file", vim.log.levels.WARN)
                return
              end

              vim.cmd("tabnew")
              vim.cmd("keepalt Gedit " .. hash .. ":" .. file.path)
            end,
            { desc = "Open file at selected commit via fugitive", silent = true },
          },
        },
      },
    },
    keys = {
      {
        keybindings.git.branchHistory.shortcut,
        "<Cmd>DiffviewFileHistory<CR>",
        desc = keybindings.git.branchHistory.desc,
      },
      {
        keybindings.git.fileHistory.shortcut,
        "<Cmd>DiffviewFileHistory --no-merges %<CR>",
        desc = keybindings.git.fileHistory.desc,
      },
      { keybindings.git.closeHistory.shortcut, ":tabclose<CR>", desc = keybindings.git.closeHistory.desc },
      {
        keybindings.git.uncommitedChanges.shortcut,
        "<Cmd>DiffviewOpen --imply-local<CR>",
        desc = keybindings.git.uncommitedChanges.desc,
      },
      { keybindings.git.review.shortcut, "<Cmd>DiffviewOpen origin/", desc = keybindings.git.review.desc },
      {
        keybindings.git.branchChanges.shortcut,
        "<Cmd>DiffviewOpen origin/HEAD...HEAD<CR>",
        desc = keybindings.git.branchChanges.desc,
      },
      {
        keybindings.git.traceLineEvolution.shortcut,
        "<Cmd>'<,'>DiffviewFileHistory<CR>",
        desc = keybindings.git.traceLineEvolution.desc,
        mode = keybindings.git.traceLineEvolution.mode,
      },
      {
        "<M-Left>",
        function()
          require("diffview.actions").prev_conflict()
        end,
        { desc = "In the merge-tool: jump to the prev conflict" },
      },
      {
        "<M-Right>",
        function()
          require("diffview.actions").next_conflict()
        end,
        { desc = "In the merge-tool: jump to the next conflict" },
      },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    keys = {
      {
        "<leader>gl",
        function()
          require("gitsigns.actions").toggle_current_line_blame()
        end,
        desc = "Toggle current line blame",
      },
    },
  },
}
