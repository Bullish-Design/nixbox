---
title: "You can remove padding around Neovim instance with this one simple trick..."
author: Evgeni Chasnovski
date: 2024-08-01
categories: [neovim, reddit]
---

*Originally [posted on Reddit](https://www.reddit.com/r/neovim/comments/1ehidxy/you_can_remove_padding_around_neovim_instance/)*

![Left: with \"frame\" from terminal emulator; Right: without that \"frame\"](2024-08-01-remove-padding-around-neovim-instance/demo.png)

(Sorry for a slightly clickbait-y title. Always wanted to use one of those :) )

If you have different background color in your terminal emulator and Neovim, then chances are that you experience this weird "frame" around your Neovim instance. Like the one shown in the left part of the picture.

This is because CLI programs occupy screen estate based on the cell grid with cells having same width and height. If pixel dimension(s) of terminal emulator's window are not multiple of cell pixel dimension(s), there is a gap between edge(s) of rendered CLI program and window edge(s).

Usual answers to this issue are:

* Use same background color in Neovim and terminal emulator. Works, but is too restrictive.
* Adjust window dimensions or DPI. Works, but is too restrictive.
* Use GUI (like Neovide). Works, but... you get the idea.

------

As it turns out, this can be solved by keeping terminal background's color in sync with Neovim's background color. This is possible thanks to a dark magic called ["Operating System Commands XTerm Control Sequences"](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands) or OSC control sequences for short. In particular, OSC 11 and OSC 111, which your terminal should support (most modern feature rich ones do: Kitty, WezTerm, Alacritty, etc.).

Just add the following snippet to your 'init.lua' (credit to u/gpanders from [this comment](https://github.com/neovim/neovim/issues/16572#issuecomment-1954420136)):

```lua
vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme" }, {
  callback = function()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    if not normal.bg then return end
    io.write(string.format("\027]11;#%06x\027\\", normal.bg))
  end,
})

vim.api.nvim_create_autocmd("UILeave", {
  callback = function() io.write("\027]111\027\\") end,
})
```

And that's it. It synchronizes on every enter/exit Neovim instance and after loading new color scheme. And it even works with `<C-z>` and later `fg`! Couple of caveats, though:

* Make sure to have this executed **before** you load color scheme. Otherwise there will be no event for it to sync. Alternatively, add an explicit call to the first `callback` function and it should work as is.
* It will not sync if you manually set `Normal` highlight group. It must be followed by the `ColorScheme` event.

------

Also, if you want a slightly more robust, maintained, and tested version, there is now a new [setup\_termbg\_sync()](https://github.com/nvim-mini/mini.nvim/blob/74e6b722c91113bc70d4bf67249ed8de0642b20e/doc/mini-misc.txt#L171) in 'mini.misc' module of 'mini.nvim'. It also checks if OSC 11 is supported by terminal emulator, uses only it without OSC 111, and synchronizes immediately.