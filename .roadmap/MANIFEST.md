# Roadmap Manifest

This file provides a quick overview of all roadmap documents and their current status.

## Document Index

| File | Stage | Name | Status | Est. Duration |
|------|-------|------|--------|---------------|
| [README.md](README.md) | - | Overview & Guide | ✅ Complete | - |
| [ROADMAP-STEP_1.md](ROADMAP-STEP_1.md) | 1 | Foundation - Storage & Data Layer | 🟡 In Progress | 2-3 weeks |
| [ROADMAP-STEP_2.md](ROADMAP-STEP_2.md) | 2 | Execution Layer - Monty Sandbox | ⚪ Not Started | 2-3 weeks |
| [ROADMAP-STEP_3.md](ROADMAP-STEP_3.md) | 3 | Orchestration Core | ⚪ Not Started | 3-4 weeks |
| [ROADMAP-STEP_4.md](ROADMAP-STEP_4.md) | 4 | UI Layer - Neovim & TMUX | ⚪ Not Started | 2-3 weeks |
| [ROADMAP-STEP_5.md](ROADMAP-STEP_5.md) | 5 | Integration & Polish | ⚪ Not Started | 3-4 weeks |

## Quick Navigation

### By Stage
- **Stage 1**: [Foundation - Storage & Data Layer](ROADMAP-STEP_1.md)
- **Stage 2**: [Execution Layer - Monty Sandbox](ROADMAP-STEP_2.md)
- **Stage 3**: [Orchestration Core](ROADMAP-STEP_3.md)
- **Stage 4**: [UI Layer - Neovim & TMUX](ROADMAP-STEP_4.md)
- **Stage 5**: [Integration & Polish](ROADMAP-STEP_5.md)

### By Topic
- **Storage**: Stage 1
- **Execution**: Stage 2
- **Orchestration**: Stage 3
- **UI**: Stage 4
- **Integration**: Stage 5
- **Testing**: All stages
- **Performance**: Stage 1, 5
- **Documentation**: Stage 5

## Current Status (Last Updated: 2026-02-13)

### Active Stage
**Stage 1: Foundation - Storage & Data Layer** 🟡

### Progress Summary
- Stages Complete: 0/5
- Overall Progress: 0%
- Next Milestone: Complete Stage 1 exit criteria

### Recent Updates
- 2026-02-13: Created complete roadmap structure with 5 stages
- 2026-02-13: Defined contracts and exit criteria for all stages
- 2026-02-13: Established testing requirements

## Stage Dependencies

```
Stage 1 (Foundation)
    ↓
Stage 2 (Execution)
    ↓
Stage 3 (Orchestration) ← depends on 1, 2
    ↓
Stage 4 (UI) ← depends on 1, 2, 3
    ↓
Stage 5 (Integration) ← depends on all previous
```

## Exit Criteria Summary

### Stage 1
- [ ] 95%+ test coverage
- [ ] All overlay semantics tested
- [ ] View query handles 10,000+ files
- [ ] Published to PyPI

### Stage 2
- [ ] Agent code execution works
- [ ] Sandbox security proven
- [ ] 90%+ test coverage
- [ ] 80%+ LLM success rate

### Stage 3
- [ ] Full agent lifecycle working
- [ ] File sync < 10ms
- [ ] Multiple agents concurrent
- [ ] 90%+ test coverage

### Stage 4
- [ ] All Neovim commands work
- [ ] TMUX preview opens < 100ms
- [ ] Ghost text displays correctly
- [ ] 80%+ test coverage

### Stage 5
- [ ] All integrations complete
- [ ] All performance targets met
- [ ] 85%+ overall coverage
- [ ] Documentation complete
- [ ] Production ready

## Performance Targets (All Stages)

| Operation | Target | Stage |
|-----------|--------|-------|
| File operations | < 10ms | 1 |
| Query operations | < 50ms | 1 |
| Code generation | < 5s | 2 |
| Code execution | < 10s | 2 |
| Agent spawn | < 1s | 3 |
| File sync | < 10ms | 3 |
| Workspace materialize | < 500ms | 3 |
| Accept/reject | < 50ms | 3 |
| Preview open | < 100ms | 4 |

## Testing Coverage Targets

| Stage | Unit | Integration | E2E | Total |
|-------|------|-------------|-----|-------|
| 1 | 70% | 20% | 10% | 95% |
| 2 | 70% | 20% | 10% | 90% |
| 3 | 60% | 30% | 10% | 90% |
| 4 | 60% | 30% | 10% | 80% |
| 5 | 40% | 40% | 20% | 85% |

## Key Contracts by Stage

### Stage 1 - Storage
- Overlay read fallthrough
- Overlay write isolation
- Multiple overlays don't interfere
- View query with filters
- Performance targets

### Stage 2 - Execution
- External functions work
- Sandbox prevents escapes
- Resource limits enforced
- LLM generates valid code
- Error handling works

### Stage 3 - Orchestration
- Agent lifecycle progresses
- Accept merges to stable
- Reject cleans up
- File changes sync
- Multiple agents concurrent

### Stage 4 - UI
- Commands create correct files
- Preview opens in TMUX
- Ghost text displays
- Keybindings work
- File watchers detect changes

### Stage 5 - Integration
- Jujutsu integration works
- GC cleans old workspaces
- Performance targets met
- Nix modules work
- Documentation complete

## Updating This Manifest

When updating stage status:
1. Change status emoji (⚪ → 🟡 → ✅)
2. Update "Last Updated" date
3. Add entry to "Recent Updates"
4. Check off completed exit criteria
5. Update progress percentages

### Status Emoji Key
- ⚪ Not Started
- 🟡 In Progress
- ✅ Complete
- ⏸️ Blocked
- ⚠️ At Risk

---

**This manifest is automatically generated from roadmap documents. Keep in sync with actual stage status.**
