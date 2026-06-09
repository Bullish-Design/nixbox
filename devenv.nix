{ ... }:
{
  # nixbox reference environment: enables the terminal interface and configures
  # the container image. `devenv container build nixbox` emits a Docker image
  # whose entrypoint starts the zellij web server (processes.nixbox).
  nixbox.enable = true;
  nixbox.webPort = 8920;
  nixbox.bind = "127.0.0.1";

  # `devenv test` runs the self-contained verification (static invariants + a
  # live check that the zellij web server binds and serves HTTP). CI can also run
  # it directly: `devenv shell nixbox-selfcheck`.
  enterTest = ''
    nixbox-selfcheck
  '';

  # Container metadata for `devenv container build nixbox`.
  # `nixbox-start` warms neovim plugins on first run (persisted via the volume
  # in compose.yaml), then starts the zellij web server.
  containers.nixbox = {
    name = "nixbox";
    startupCommand = "nixbox-start";
  };
}
