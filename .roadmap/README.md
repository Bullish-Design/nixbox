# Nixbox/Cairn Development Roadmap

This directory contains the complete development roadmap for the nixbox/cairn project, organized into 5 distinct stages with clear deliverables and exit criteria.

## Overview

The roadmap follows a **stagegate development model** where each stage must be fully completed and tested before proceeding to the next. This ensures a solid foundation and prevents technical debt.

## Roadmap Stages

| Stage | Name | Duration | Dependencies | Status |
|-------|------|----------|--------------|--------|
| [1](ROADMAP-STEP_1.md) | Foundation - Storage & Data Layer | 2-3 weeks | None | ✅ Complete |
| [2](ROADMAP-STEP_2.md) | Execution Layer - Monty Sandbox | 2-3 weeks | Stage 1 | ✅ Complete |
| [3](ROADMAP-STEP_3.md) | Orchestration Core | 3-4 weeks | Stage 1, 2 | ✅ Complete |
| [4](ROADMAP-STEP_4.md) | UI Layer - Neovim & TMUX | 2-3 weeks | Stage 1, 2, 3 | 🟡 Ready to Start |
| [5](ROADMAP-STEP_5.md) | Integration & Polish | 3-4 weeks | All previous | ⚪ Not Started |

**Total Estimated Duration**: 12-17 weeks

**Current Milestone**: Stage 3 complete; Stage 4 is now unblocked.

## Stage Summaries

### Stage 1: Foundation - Storage & Data Layer
**Goal**: Complete and thoroughly test the `agentfs-pydantic` library

**Key Deliverables**:
- Pydantic models for all AgentFS objects
- View query system with filters
- Overlay semantics tested and proven
- Performance benchmarks met
- Published to PyPI

**Why First**: Everything builds on storage. Must be bulletproof.

---

### Stage 2: Execution Layer - Monty Sandbox
**Goal**: Safe, reliable agent code execution

**Key Deliverables**:
- External function interface
- Monty sandbox integration
- LLM code generation
- Resource limits enforced
- Security tested and proven

**Why Second**: Can't orchestrate agents without safe execution.

---

### Stage 3: Orchestration Core
**Goal**: Complete agent lifecycle (headless, no UI)

**Key Deliverables**:
- Agent lifecycle (QUEUED → REVIEWING)
- File watching and sync
- Workspace materialization
- Task queue with priorities
- Accept/reject via signals
- CLI interface for testing

**Why Third**: UI needs a working orchestrator to interact with.

---

### Stage 4: UI Layer - Neovim & TMUX
**Goal**: Developer-friendly interface

**Key Deliverables**:
- Neovim plugin with commands
- TMUX integration
- Ghost text display
- Keybindings (<leader>a, <leader>r, <leader>p)
- File watchers for updates

**Why Fourth**: Adds ergonomic layer on top of working orchestrator.

---

### Stage 5: Integration & Polish
**Goal**: Production-ready system

**Key Deliverables**:
- Jujutsu integration
- Garbage collection
- Performance optimization
- Nix modules (agentfs.nix, cairn.nix)
- Complete documentation
- Example configurations

**Why Last**: Polish and optimize after core functionality works.

---

## Stagegate Process

### Entry Criteria
Before starting a stage:
- [ ] All previous stages complete
- [ ] All previous stage tests passing
- [ ] Previous stage documentation updated
- [ ] Team review of previous stage

### During Stage
For each stage:
- [ ] Follow TDD (test-driven development)
- [ ] Update documentation as you go
- [ ] Run tests continuously
- [ ] Profile performance regularly
- [ ] Update SKILL guides with new patterns

### Exit Criteria
Before proceeding to next stage:
- [ ] All deliverables complete
- [ ] All tests passing (unit, integration, E2E)
- [ ] Code coverage targets met
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Contracts verified

### Gate Review
At each stagegate:
1. **Demo**: Show working functionality
2. **Test Review**: Verify all tests pass
3. **Performance Review**: Check benchmarks
4. **Documentation Review**: Ensure clarity
5. **Go/No-Go Decision**: Proceed or address issues

---

## Using the Roadmap

### For AI Agents

When starting work on a stage:
1. Read `ROADMAP-STEP_<num>.md` for that stage
2. Understand the **Contracts** - these are your acceptance tests
3. Write tests first, then implement to pass the tests
4. Reference the **Contracts** sections for expected behavior
5. Check **Exit Criteria** before claiming completion

### For Human Developers

The roadmap provides:
- **Clear milestones**: Know what's next
- **Success metrics**: Know when you're done
- **Risk mitigation**: Address hard problems early
- **Incremental value**: Each stage delivers something usable

### For Project Management

Track progress using:
- **Stage status**: Which stage are we in?
- **Exit criteria**: How many criteria remain?
- **Test coverage**: Are we meeting targets?
- **Performance benchmarks**: Are we on track?

---

## Contract-Driven Development

Each roadmap document includes **Contracts** - explicit specifications of expected behavior. These are:

- **Testable**: Every contract has a corresponding test
- **Specific**: No ambiguity about what should happen
- **Complete**: Cover all important behavior
- **Documented**: Serve as documentation of system behavior

Example contract:
```python
# Contract 1: Overlay read fallthrough
async def test_overlay_read_fallthrough():
    """Agent reads from stable if file not in overlay"""
    stable = await AgentFS.open(AgentFSOptions(id="test-stable"))
    agent = await AgentFS.open(AgentFSOptions(id="test-agent"))

    # Write to stable
    await stable.fs.write_file("test.txt", b"stable content")

    # Read from agent (should fall through to stable)
    content = await agent.fs.read_file("test.txt")
    assert content == b"stable content"
```

### Benefits of Contracts

1. **Clarity**: No ambiguity about expected behavior
2. **Testability**: Contracts become tests directly
3. **Documentation**: Self-documenting system behavior
4. **Validation**: Clear criteria for completion

---

## Adapting the Roadmap

The roadmap is not set in stone. Adjustments may be needed based on:

### Discovered Complexity
If a stage is more complex than expected:
- Split into sub-stages
- Adjust duration estimates
- Add intermediate milestones

### Technical Challenges
If a technical challenge blocks progress:
- Re-order stages if dependencies allow
- Add spike tasks to derisk
- Adjust approach if needed

### Changing Requirements
If requirements change:
- Update affected roadmap documents
- Re-validate exit criteria
- Communicate changes to team

### Process
To modify the roadmap:
1. Propose change with rationale
2. Review impact on dependencies
3. Update roadmap documents
4. Communicate changes

---

## Success Metrics

### Overall Project
- [ ] All 5 stages complete
- [ ] All performance targets met
- [ ] 85%+ test coverage overall
- [ ] Complete documentation
- [ ] v1.0 release ready

### Stage-Level
Each stage tracks:
- Test coverage (unit, integration, E2E)
- Performance benchmarks
- Code quality metrics
- Documentation completeness

### Continuous
Throughout development:
- Tests always passing
- No critical bugs
- Documentation stays current
- Performance doesn't regress

---

## Timeline

Based on 5 stages with estimated durations:

```
Stage 1: Weeks 1-3   (Foundation)
Stage 2: Weeks 4-6   (Execution)
Stage 3: Weeks 7-10  (Orchestration)
Stage 4: Weeks 11-13 (UI)
Stage 5: Weeks 14-17 (Polish)

Total: 12-17 weeks
```

**Note**: Timeline assumes full-time development. Adjust for part-time or multiple contributors.

---

## Getting Help

If you're stuck on a stage:
1. Review the **Key Risks** section in the roadmap
2. Check the **SKILL guides** for patterns
3. Look at **contracts** for expected behavior
4. Review previous stages for examples
5. Ask for help with specific questions

---

## Related Documentation

- [SPEC.md](../SPEC.md) - Technical specification
- [CONCEPT.md](../CONCEPT.md) - Design philosophy
- [AGENT.md](../AGENT.md) - Agent development guide
- [.agent/skills/](../.agent/skills/) - Subsystem skills

---

**Remember**: The roadmap is a guide, not a prison. Use good judgment, communicate changes, and focus on building something great!
