---
title: "Neovim now has built-in commenting"
author: Evgeni Chasnovski
date: 2024-04-05
categories: [neovim, reddit]
---

*Originally [posted on Reddit](https://www.reddit.com/r/neovim/comments/1bwlvrt/neovim_now_has_builtin_commenting/)*

[The PR for built-in commenting](https://github.com/neovim/neovim/pull/28176) has been merged into Nightly builds. There is more info in the initial PR comment and [help entry](https://github.com/neovim/neovim/blob/73de98256cf3932dca156fbfd0c82c1cc10d487e/runtime/doc/various.txt#L561-L597), but for the lazy:

- All it does is out of the box mappings:
    - `gc` operator (Normal and Visual mode) to toggle comments.
    - `gc` textobject (Operator-pending mode) as operator target.
    - `gcc` for toggling comments in current line (basically a convenient `gc_` remap).

    Also, of course, dot-repeat, `[count]` support, etc.

- This is basically a simplified version of ['mini.commment'](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-comment.md) with *mostly* default config.

  The `pad_comment_parts` is `false` meaning that 'commentstring' option is taken as is, without forcing single space padding. This is planned to be addressed by adjusting default 'commentstring' values some time later (at least after 0.10.0 release) or can be done by users themselves in their configs.

- On the surface it is quite close to 'tpope/vim-commentary', but with some difference in how it handles blank lines: blank lines are commented but do not affect the toggle action decision. See example in [this comment](https://github.com/neovim/neovim/pull/28176#issuecomment-2039299762).

So if you are using only basics of 'mini.comment' (no custom hooks, options, or callable 'commentstring's) or 'tpope/vim-commentary', you might find the new built-in commenting on Nightly to be enough.