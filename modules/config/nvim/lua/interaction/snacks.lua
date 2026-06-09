require("snacks").setup({
  dashboard = require("interaction.dashboard"),
  picker = require("interaction.picker"),
  explorer = require("interaction.explorer"),
  scratch = require("interaction.scratch"),
  git = { enabled = true },
  terminal = require("interaction.terminal"),
  bigfile = { enabled = true },
  input = { enabled = false },
  words = { enabled = false },
  scope = { enabled = true },
  zoom = { enabled = true },
  image = { enabled = true },

  notifier = { enabled = true },
})
