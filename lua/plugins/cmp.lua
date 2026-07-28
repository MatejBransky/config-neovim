local keybindings = require("keybindings")

return {
  {
    "blink.cmp",
    opts = {
      keymap = {
        preset = "default",
        ["<Tab>"] = false,
        ["<S-Tab>"] = false,
        [keybindings.snippet.jumpNext.shortcut] = { "snippet_forward" },
        [keybindings.snippet.jumpPrev.shortcut] = { "snippet_backward" },
      },
    },
  },
}
