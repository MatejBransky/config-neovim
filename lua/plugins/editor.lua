return {
  "MagicDuck/grug-far.nvim",
  keys = {
    {
      "<leader>r",
      function()
        require("grug-far").open({ visualSelectionUsage = "operate-within-range" })
      end,
      mode = { "v" },
    },
  },
}
