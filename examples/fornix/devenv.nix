{ config, ... }:
{
  nixbox.enable = true;

  # Key trick for fornix: keep vim.pack's plugin data *inside the workspace*
  # (instead of ~/.local/share) so fornix's btrfs-subvolume fork carries the
  # preseeded plugins into the sandbox. Combined with the vendored zellij .wasm,
  # this means the sandbox needs no network at run time (fornix default:
  # FORNIX_NETWORK=none).
  env.XDG_DATA_HOME = "${config.devenv.root}/.nixbox/data";
  env.XDG_CACHE_HOME = "${config.devenv.root}/.nixbox/cache";
}
