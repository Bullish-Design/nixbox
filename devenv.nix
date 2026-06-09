{ ... }:
{
  # nixbox reference environment: enables the terminal interface and configures
  # the container image. `devenv container build nixbox` emits a Docker image
  # whose entrypoint starts the zellij web server (processes.nixbox).
  nixbox.enable = true;
  nixbox.webPort = 8920;
  nixbox.bind = "127.0.0.1";

  # Container metadata for `devenv container build nixbox`.
  # `nixbox-start` warms neovim plugins on first run (persisted via the volume
  # in compose.yaml), then starts the zellij web server.
  containers.nixbox = {
    name = "nixbox";
    startupCommand = "nixbox-start";
  };
}
