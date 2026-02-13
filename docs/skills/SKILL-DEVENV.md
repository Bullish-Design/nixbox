# SKILL: Nix/devenv Module Development

Quick reference for developing Nix modules for nixbox.

## Module Structure

```nix
# modules/agentfs.nix
{ inputs, pkgs, config, ... }:
{
  packages = [ agentfsPackage ];
  
  env = {
    AGENTFS_HOST = lib.mkDefault "127.0.0.1";
    AGENTFS_PORT = lib.mkDefault "8081";
  };
  
  processes.agentfs = lib.mkIf agentfsEnabled {
    exec = agentfsServe;
  };
  
  scripts.agentfs-info.exec = ''
    echo "AgentFS running on $AGENTFS_HOST:$AGENTFS_PORT"
  '';
}
```

## Composition

```nix
# devenv.nix
{
  imports = [
    ./nixbox/modules/agentfs.nix
    ./nixbox/modules/cairn.nix
  ];
}
```

## Building Packages

```nix
agentfsPackage = rustPlatform.buildRustPackage {
  pname = "agentfs";
  version = "0.6.0";
  src = ./vendor/agentfs;
  cargoLock.lockFile = ./vendor/agentfs/Cargo.lock;
};
```

## See Also
- [devenv.sh Docs](https://devenv.sh/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
