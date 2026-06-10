# Single source of truth for the vendored Zellij plugins. Consumed by:
#   - modules/zellij/default.nix      (URL->file: rewrite + pre-granted permissions)
#   - scripts/fetch-zellij-plugins.sh (download, via `nix eval`)
#
# The attr NAME is the vendored basename: <name> -> config/zellij/plugins/<name>.wasm.
# To add/remove a plugin, edit ONLY this file (then re-run scripts/fetch-zellij-plugins.sh
# to vendor the new .wasm). The rewrite, permissions, fetch list, and selfcheck count all
# derive from here, so they can't drift.
{
  autolock  = "https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm";
  attention = "https://github.com/KiryuuLight/zellij-attention/releases/latest/download/zellij-attention.wasm";
  bookmarks = "https://github.com/yaroslavborbat/zellij-bookmarks/releases/latest/download/zellij-bookmarks.wasm";
  zjstatus  = "https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm";
}
