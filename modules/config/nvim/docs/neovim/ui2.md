
==============================================================================
UI2                                                                      *ui2*

WARNING: This is an experimental feature intended to replace the builtin
message + cmdline presentation layer.

To enable this feature (default opts shown): >lua
    require('vim._core.ui2').enable({
      enable = true, -- Whether to enable or disable the UI.
      msg = { -- Options related to the message module.
        ---@type string|table<string, 'cmd'|'msg'|'pager'> Default message target
        ---or table mapping |ui-messages| kinds, triggers and IDs to a target.
        ---Table keys are are matched as a Lua pattern to the message ID. 'default'
        ---mapping applies to any omitted kind: { default = 'cmd', progress = 'msg' }.
        targets = 'cmd',
        cmd = { -- Options related to messages in the cmdline window.
          -- Maximum height (rows if >=1, or % of 'lines' if <1) of messages expanded
          -- beyond 'cmdheight'; 0.999 for full height.
          height = 0.5,
        },
        dialog = { -- Options related to dialog window.
          height = 0.5, -- Maximum height.
        },
        msg = { -- Options related to msg window.
          height = 0.5, -- Maximum height.
          timeout = 4000, -- Time a message is visible in the message window.
        },
        pager = { -- Options related to message window.
          height = 0.999, -- Maximum height.
        },
      },
    })
<

There are four special windows/buffers for presenting messages and cmdline:
• "cmd": Cmdline. Also used for 'showcmd', 'showmode', 'ruler', and messages
  by default.
• "msg": Message window, shows ephemeral messages useful for 'cmdheight' == 0.
• "pager": Pager window, shows |:messages| and certain messages that are never
  "collapsed".
• "dialog": Dialog window, shows modal prompts that expect user input.

The buffer 'filetype' is set to the above-listed id ("cmd", "msg", …).
Handle the |FileType| event to configure any local options for these windows
and their respective buffers.

Unlike the legacy |hit-enter| prompt, messages exceeding 'cmdheight' are
instead "collapsed", followed by a `[+x]` "spill" indicator, where `x`
indicates the spilled lines. To see the full messages, do either:
• ENTER immediately after interactive |:| cmdline shows a message and returns
  to |Normal-mode|.
• |g<| at any time.