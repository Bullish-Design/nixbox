# nixbox Library Development Roadmap - Overview

This document provides an overview of the development roadmap for expanding the `agentfs-pydantic` library into a comprehensive Python interface for AgentFS.

## Vision

Transform `agentfs-pydantic` from a basic Pydantic model library into a full-featured, type-safe Python interface for AgentFS that:
- Provides complete CLI command wrappers
- Manages AgentFS lifecycle (start/stop/health checks)
- Integrates seamlessly with devenv.sh environments
- Offers high-level convenience APIs for common workflows
- Includes robust error handling and observability
- Provides testing utilities for TDD workflows

## Current State

The library currently provides:
- ✅ Pydantic models for filesystem entries, stats, tool calls, KV entries
- ✅ View-based query interface for filesystem traversal
- ✅ Type-safe options for AgentFS initialization
- ✅ Async-first API design

## Development Phases

### Phase 1: Core (MVP)
Foundation for all CLI interactions and process management.

| Step | Guide | Description | Dependencies |
|------|-------|-------------|--------------|
| 1 | [DEV_GUIDE-STEP_01.md](./DEV_GUIDE-STEP_01.md) | CLI Binary Wrapper | None |
| 2 | [DEV_GUIDE-STEP_02.md](./DEV_GUIDE-STEP_02.md) | Enhanced Models | Step 1 |
| 3 | [DEV_GUIDE-STEP_03.md](./DEV_GUIDE-STEP_03.md) | Init/Exec/Run Operations | Steps 1-2 |
| 4 | [DEV_GUIDE-STEP_04.md](./DEV_GUIDE-STEP_04.md) | AgentFSManager Lifecycle | Steps 1-3 |
| 5 | [DEV_GUIDE-STEP_05.md](./DEV_GUIDE-STEP_05.md) | devenv.sh Integration | Steps 1-4 |

**Milestone**: Can programmatically start AgentFS, run commands, and integrate with devenv.sh environments.

### Phase 2: Essential
Core filesystem operations and resource management.

| Step | Guide | Description | Dependencies |
|------|-------|-------------|--------------|
| 6 | [DEV_GUIDE-STEP_06.md](./DEV_GUIDE-STEP_06.md) | Mount/Unmount Operations | Phase 1 |
| 7 | [DEV_GUIDE-STEP_07.md](./DEV_GUIDE-STEP_07.md) | Filesystem Operations | Phase 1 |
| 8 | [DEV_GUIDE-STEP_08.md](./DEV_GUIDE-STEP_08.md) | Error Handling Hierarchy | Phase 1 |
| 9 | [DEV_GUIDE-STEP_09.md](./DEV_GUIDE-STEP_09.md) | Context Managers | Steps 6-8 |

**Milestone**: Full filesystem manipulation with proper error handling and resource cleanup.

### Phase 3: Advanced
Advanced features for sync, timeline, and server operations.

| Step | Guide | Description | Dependencies |
|------|-------|-------------|--------------|
| 10 | [DEV_GUIDE-STEP_10.md](./DEV_GUIDE-STEP_10.md) | Sync Operations | Phase 2 |
| 11 | [DEV_GUIDE-STEP_11.md](./DEV_GUIDE-STEP_11.md) | Timeline Queries | Phase 2 |
| 12 | [DEV_GUIDE-STEP_12.md](./DEV_GUIDE-STEP_12.md) | Diff Operations | Phase 2 |
| 13 | [DEV_GUIDE-STEP_13.md](./DEV_GUIDE-STEP_13.md) | Migration Support | Phase 2 |
| 14 | [DEV_GUIDE-STEP_14.md](./DEV_GUIDE-STEP_14.md) | MCP/NFS Servers | Phase 2 |

**Milestone**: Complete feature parity with AgentFS CLI, including advanced operations.

### Phase 4: Quality
Developer experience improvements and ecosystem integration.

| Step | Guide | Description | Dependencies |
|------|-------|-------------|--------------|
| 15 | [DEV_GUIDE-STEP_15.md](./DEV_GUIDE-STEP_15.md) | Observer/Event System | Phase 3 |
| 16 | [DEV_GUIDE-STEP_16.md](./DEV_GUIDE-STEP_16.md) | Testing Utilities | Phase 3 |
| 17 | [DEV_GUIDE-STEP_17.md](./DEV_GUIDE-STEP_17.md) | High-Level Convenience APIs | Phase 3 |
| 18 | [DEV_GUIDE-STEP_18.md](./DEV_GUIDE-STEP_18.md) | Documentation & Examples | All phases |

**Milestone**: Production-ready library with excellent DX, comprehensive docs, and test support.

## Design Principles

All development should follow these principles:

1. **Type Safety First**: Everything validated with Pydantic
2. **Async Native**: All I/O operations are async
3. **Context Managers**: RAII pattern for resource management
4. **Sensible Defaults**: Work out-of-box for common cases
5. **Composable**: Small, focused functions that combine well
6. **Observable**: Events for monitoring and debugging
7. **Testable**: Built-in test utilities
8. **devenv.sh Native**: First-class integration with devenv environments

## Module Structure

The final library structure will be:

```
agentfs-pydantic/
├── src/agentfs_pydantic/
│   ├── __init__.py          # Main exports
│   ├── models.py            # All Pydantic models (existing + new)
│   ├── cli.py               # CLI wrapper (AgentFSCLI, AgentFSBinary)
│   ├── manager.py           # Lifecycle management (AgentFSManager)
│   ├── devenv.py            # devenv.sh integration
│   ├── view.py              # Existing View interface (keep)
│   ├── sync.py              # Sync operations
│   ├── mount.py             # Mount/unmount operations
│   ├── serve.py             # MCP/NFS servers
│   ├── filesystem.py        # Filesystem operations
│   ├── timeline.py          # Timeline queries
│   ├── diff.py              # Diff operations
│   ├── migration.py         # Migration support
│   ├── exceptions.py        # Error hierarchy
│   ├── observer.py          # Event observers
│   ├── convenience.py       # High-level convenience APIs
│   └── testing.py           # Test utilities
├── tests/
│   ├── test_cli.py
│   ├── test_manager.py
│   ├── test_devenv.py
│   ├── test_mount.py
│   ├── test_sync.py
│   └── ...
└── examples/
    ├── basic_usage.py
    ├── lifecycle_management.py
    ├── devenv_integration.py
    ├── sandboxed_execution.py
    └── ...
```

## Getting Started

1. **Read this overview** to understand the big picture
2. **Start with Phase 1** - each guide builds on previous work
3. **Follow the guide structure** - each step includes:
   - Clear objectives
   - Prerequisites check
   - Step-by-step implementation
   - Code examples
   - Testing guidelines
   - Success criteria
4. **Test as you go** - write tests for each component
5. **Reference BRAINSTORM.md** for detailed API examples

## Key Resources

- [BRAINSTORM.md](../BRAINSTORM.md) - Detailed functionality specifications
- [AgentFS Documentation](https://docs.turso.tech/agentfs)
- [AgentFS CLI Reference](https://docs.turso.tech/agentfs/cli)
- [Pydantic Documentation](https://docs.pydantic.dev/)

## Success Metrics

The completed library will:
- ✅ Reduce AgentFS integration code by 80%
- ✅ Provide type safety for all operations
- ✅ Work seamlessly in devenv.sh environments
- ✅ Enable TDD with built-in test utilities
- ✅ Have comprehensive documentation with examples
- ✅ Support both simple scripts and complex applications

## Questions & Support

If you encounter issues or have questions:
1. Check the specific step guide for troubleshooting tips
2. Review the BRAINSTORM.md for API design rationale
3. Consult AgentFS documentation for CLI behavior
4. Open an issue in the repository

## Contributing

When implementing each step:
- Follow the guide closely
- Write tests before marking a step complete
- Update the checklist in each guide as you progress
- Document any deviations or improvements
- Keep code simple and readable
- Add type hints everywhere
- Write docstrings for public APIs

Happy building! 🚀
