{ pkgs, lib, ... }:

let
  enabled = builtins.getEnv "AGENTFS_ENABLED" != "0";
in
{
  packages = [
    pkgs.git
    pkgs.curl
    pkgs.turso-cli
  ];

  env = {
    AGENTFS_ENABLED = lib.mkDefault "1";
    AGENTFS_HOST = lib.mkDefault "127.0.0.1";
    AGENTFS_PORT = lib.mkDefault "8081";
    AGENTFS_DATA_DIR = lib.mkDefault ".devenv/state/agentfs";
    AGENTFS_DB_NAME = lib.mkDefault "sandbox";
    AGENTFS_LOG_LEVEL = lib.mkDefault "info";
    AGENTFS_EXTRA_ARGS = lib.mkDefault "";
  };

  processes.agentfs = lib.mkIf enabled {
    exec = ''
      mkdir -p "$AGENTFS_DATA_DIR"
      exec turso agentfs serve \
        --host "$AGENTFS_HOST" \
        --port "$AGENTFS_PORT" \
        --data-dir "$AGENTFS_DATA_DIR" \
        --db "$AGENTFS_DB_NAME" \
        --log-level "$AGENTFS_LOG_LEVEL" \
        $AGENTFS_EXTRA_ARGS
    '';
  };

  scripts.agentfs-info.exec = ''
    cat <<INFO
AgentFS process configuration
-----------------------------
Enabled:   $AGENTFS_ENABLED
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
    devenv run agentfs-info
  '';
}
