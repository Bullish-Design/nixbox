# devenv.nix
{ pkgs, lib, config, ... }:

{
  # Core packages needed for the project
  packages = with pkgs; [
    # Python ecosystem
    python311
    uv

    # File watching and monitoring
    inotify-tools

    # Database
    sqlite

    # Text processing and search
    tree
    ripgrep
    fd
    diffutils

    # LLM backend
    ollama
  ];

  # Python language configuration
  languages.python = {
    enable = true;
    version = "3.11";
    uv = {
      enable = true;
    };
  };

  # Background processes
  processes = {
    # Ollama server for LLM inference
    ollama = {
      exec = "ollama serve";
    };
  };

  # Convenient scripts
  scripts = {
    # Run the orchestrator
    chimera = {
      exec = "uv run chimera.py";
      description = "Start the Chimera orchestrator";
    };

    # Pull the default model
    pull-model = {
      exec = "ollama pull qwen2.5-coder:7b";
      description = "Download the default Qwen coder model";
    };

    # Initialize stable layer from current directory
    init-stable = {
      exec = "uv run init_stable.py";
      description = "Initialize stable.db from current project";
    };

    # View agent database
    inspect-agent = {
      exec = "sqlite3 .agentfs/\${1:-stable}.db";
      description = "Inspect an agent database (default: stable)";
    };
  };

  # Shell hooks
  enterShell = ''
    echo "🎭 Chimera Development Environment"
    echo ""
    echo "Available commands:"
    echo "  chimera      - Start the orchestrator"
    echo "  pull-model   - Download qwen2.5-coder:7b"
    echo "  init-stable  - Initialize stable layer"
    echo ""
    echo "Ollama will start automatically in the background."
    echo ""
    
    # Create necessary directories
    mkdir -p .agentfs
    mkdir -p ~/.chimera/previews
    mkdir -p ~/.chimera/signals
  '';
}
