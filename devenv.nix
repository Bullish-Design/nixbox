{ pkgs, config, ... }:

let
  lib = pkgs.lib;
  root = config.git.root;

  envOrDefault = name: default:
    let v = builtins.getEnv name;
    in if v != "" then v else default;

  # Enabled unless explicitly disabled: AGENTFS_ENABLED=0
  agentfsEnabled = (config.env.AGENTFS_ENABLED or "1") != "0";
  agentfsEnabledLabel = if agentfsEnabled then "yes" else "no";

  agentfsServe = ''
    cd "${root}"
    mkdir -p "$AGENTFS_DATA_DIR"
    exec turso agentfs serve \
      --host "$AGENTFS_HOST" \
      --port "$AGENTFS_PORT" \
      --data-dir "$AGENTFS_DATA_DIR" \
      --db "$AGENTFS_DB_NAME" \
      --log-level "$AGENTFS_LOG_LEVEL" \
      $AGENTFS_EXTRA_ARGS
  '';
in
{
  packages = with pkgs; [
    git
    curl
    turso-cli

    # QoL tooling
    jq
    ripgrep
    just
  ];

  env = {
    # Default can be overridden by your shell env (AGENTFS_ENABLED=0) or by devenv config.
    AGENTFS_ENABLED = lib.mkDefault (envOrDefault "AGENTFS_ENABLED" "1");

    AGENTFS_HOST = lib.mkDefault "127.0.0.1";
    AGENTFS_PORT = lib.mkDefault "8081";

    # Keep state anchored under the repo root (works no matter where you run from).
    AGENTFS_DATA_DIR = lib.mkDefault "${root}/.devenv/state/agentfs";

    AGENTFS_DB_NAME = lib.mkDefault "sandbox";
    AGENTFS_LOG_LEVEL = lib.mkDefault "info";
    AGENTFS_EXTRA_ARGS = lib.mkDefault "";
  };

  processes.agentfs = lib.mkIf agentfsEnabled {
    exec = agentfsServe;
  };

  # Stable command interfaces live here; workflow tweaks can live elsewhere.
  scripts.agentfs.exec = agentfsServe;

  scripts.agentfs-info.exec = ''
    cd "${root}"
    cat <<INFO
AgentFS process configuration
-----------------------------
Repo root: ${root}
Enabled:   $AGENTFS_ENABLED (shell), ${agentfsEnabledLabel} (eval)
Host:      $AGENTFS_HOST
Port:      $AGENTFS_PORT
Data dir:  $AGENTFS_DATA_DIR
DB name:   $AGENTFS_DB_NAME
Log level: $AGENTFS_LOG_LEVEL
Extra:     $AGENTFS_EXTRA_ARGS
INFO
  '';

  scripts.agentfs-url.exec = ''
    echo "http://$AGENTFS_HOST:$AGENTFS_PORT"
  '';

  enterShell = ''
    echo
    echo --------------------------------------------------------
    echo
    echo " AgentFS development environment "
    echo
    echo " Useful commands:"
    echo "   agentfs-info   # show current AgentFS config"
    echo "   agentfs-url    # print the base URL"
    echo "   agentfs        # run AgentFS in the foreground"
    echo "   devenv up       # run background processes (includes agentfs)"
    echo
    echo --------------------------------------------------------
    echo
    cd "${root}"
    echo "PWD: $(pwd)"
    echo
    devenv run agentfs-info
  '';
}

