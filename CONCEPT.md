# Cairn: Conceptual Foundation

> **cairn** (noun): A mound of rough stones built as a memorial or landmark, typically on a hilltop or skyline. Each traveler adds a stone.

## The Core Metaphor

Traditional collaborative development is like **git branches** - diverging timelines that must be carefully merged. You switch contexts, resolve conflicts, hope nothing breaks.

Cairn is different. It's a **pile**.

- You put stones on the pile (your changes)
- Agents suggest stones for the pile (their changes)
- You pick which suggested stones to add (accept)
- You discard stones you don't want (reject)

**No branching. No merging. No conflicts. Just a growing pile.**

## Why This Metaphor Matters

### Traditional AI Coding (Copilot/Cursor)

```
┌─────────────────────────────────────┐
│ You + AI share the same cursor     │
│ Fighting for control                │
│ Accept or reject suggestions        │
│ One at a time                       │
└─────────────────────────────────────┘
```

**Problem:** Interrupts flow. You're either writing or accepting AI suggestions, never both.

### Agent-Based Coding (Devin, etc.)

```
┌─────────────────────────────────────┐
│ Agent has full control              │
│ Works in isolated environment       │
│ You watch via chat/screen           │
│ Hope it does what you want          │
└─────────────────────────────────────┘
```

**Problem:** Loss of control. You're a spectator, not a collaborator.

### Cairn (This Project)

```
┌─────────────────────────────────────┐
│ You work in stable layer            │
│ Agents work in overlays             │
│ You see proposals via ghost text    │
│ You decide what to merge            │
│ Both work simultaneously            │
└─────────────────────────────────────┘
```

**Benefit:** True parallel collaboration. You build, agents suggest, you choose.

## The Pile Model vs. The Branch Model

### Branch Model (Git)

```
main ─┬─ feature1
      ├─ feature2
      └─ feature3

Merge: Complex 3-way merge, conflicts, rebases
```

**Branches:**
- Diverge from a point in time
- Must be merged back
- Conflicts resolved manually
- Context switching required

### Pile Model (Cairn)

```
stable ← base layer

agent1 ↓  overlay (read stable, write own)
agent2 ↓  overlay (read stable, write own)
agent3 ↓  overlay (read stable, write own)

Accept: Copy overlay → stable (simple)
```

**Overlays:**
- Always based on current stable
- Never merge, just copy or discard
- No conflicts (last write wins)
- No context switching (tmux panes)

## Core Principles

### 1. Copy-on-Write, Not Merge

Agents don't fork your code. They create an **overlay** that shadows your stable layer.

```python
# Agent reads
content = read_file("main.py")  # From overlay, falls through to stable

# Agent writes
write_file("main.py", modified)  # Only to overlay, stable unchanged

# You accept
# → Simply copy overlay's main.py to stable.db
# → No merge algorithm needed
```

### 2. Isolation, Not Integration

Agents never touch your stable layer until you say so.

```
┌─────────────────────────────────────┐
│ Stable Layer (main.py)              │
│                                      │
│ def hello():                         │
│     print("hello")                   │
└─────────────────────────────────────┘
        ↓ Agent reads
┌─────────────────────────────────────┐
│ Agent Overlay (main.py)              │
│                                      │
│ def hello():                         │
│     """Say hello to user."""         │
│     print("hello")                   │
└─────────────────────────────────────┘
        ↓ You accept
┌─────────────────────────────────────┐
│ Stable Layer (main.py) ← copied      │
│                                      │
│ def hello():                         │
│     """Say hello to user."""         │
│     print("hello")                   │
└─────────────────────────────────────┘
```

### 3. Sandboxing, Not Trust

Agents run in a minimal Python interpreter (Monty) with:

- ❌ No imports
- ❌ No file access (except via functions you provide)
- ❌ No network access (except via functions you provide)
- ❌ No environment variables
- ❌ No subprocess calls
- ✅ Only: variables, functions, loops, conditionals

**Worst case:** Agent generates garbage code that wastes CPU. Can't damage your project.

### 4. Materialization, Not Mounting

Instead of complex FUSE mounts, just **copy files to disk**:

```bash
~/.cairn/workspaces/agent-abc123/
├── main.py          # Modified by agent
├── utils.py         # Modified by agent
└── config.json      # Unchanged (hardlink to stable)
```

**Why?**
- LSP works (language server sees real files)
- Linters work (tools see real files)
- Tests work (test runner sees real files)
- Builds work (build tools see real files)

You can literally `cd` into the agent's workspace and use all your normal tools.

### 5. Preview, Don't Peek

Instead of ghost text (which is hard to test), open **a whole new editor** in tmux:

```
┌──────────────┬──────────────┐
│ Stable Nvim  │ Preview Nvim │
│              │              │
│ Your work    │ Agent's work │
│              │              │
│ Live editing │ Testing zone │
└──────────────┴──────────────┘
```

Switch with `Ctrl-b o`. Run tests. Check builds. Then accept or reject.

### 6. Jujutsu, Not Git

Git thinks in terms of **commits** (immutable snapshots).

Jujutsu thinks in terms of **changes** (evolving descriptions of work).

Cairn thinks in terms of **overlays** (proposed additions).

**Mapping:**
```
Cairn Overlay     →  JJ Change
Accept overlay    →  jj squash
Reject overlay    →  jj abandon
Preview workspace →  jj working copy at change
```

This is a natural fit. Agents create changes. You decide whether to squash them into your working copy.

## The Three Layers

### 1. Storage Layer (AgentFS)

SQLite databases with inode-based filesystem:

```
.agentfs/
├── stable.db           # Ground truth
├── agent-abc123.db     # Agent 1's overlay
├── agent-def456.db     # Agent 2's overlay
└── bin.db              # GC tracker
```

Each database is independent. Overlays read from stable, write to self.

### 2. Execution Layer (Monty)

Minimal Python interpreter:

```python
# What agents can do:
files = search_files("*.py")
for file in files:
    content = read_file(file)
    if needs_docstrings(content):
        new_content = ask_llm("Add docstrings", content)
        write_file(file, new_content)

submit_result("Added docstrings", files)
```

No imports, no file I/O, no network. Just logic.

### 3. Orchestration Layer (Cairn)

Python asyncio process that:

1. Watches stable layer for human changes (inotify)
2. Spawns agents with tasks (creates overlay)
3. Provides external functions to Monty (read/write/llm)
4. Generates diffs (stable vs overlay)
5. Materializes workspaces (for preview)
6. Handles accept/reject (copy or delete)
7. Garbage collects dead overlays

## The Developer Experience

### Without Cairn

```
1. Write code
2. Think "I should add docstrings"
3. Start adding docstrings
4. Get interrupted by meeting
5. Context switch back
6. Finish docstrings
7. Maybe ask AI for help
8. Accept AI suggestions one by one
9. Continue coding
```

**Time:** 30 minutes. **Focus:** Broken.

### With Cairn

```
1. Write code
2. Think "I should add docstrings"
3. :CairnQueue "Add docstrings"
4. Continue writing code (uninterrupted)
5. Agent finishes, ghost text appears
6. <Leader>p opens preview
7. Check docstrings in preview
8. <Leader>a accepts
9. Continue coding
```

**Time:** 2 minutes active (28 minutes parallel). **Focus:** Maintained.

## Design Non-Goals

Things Cairn explicitly does NOT try to do:

### ❌ Multi-User Collaboration

Cairn is single-developer. For teams, use git/jj.

**Why:** Multi-user requires CRDTs, conflict resolution, synchronization - complexity that doesn't pay off.

### ❌ Long-Running Agent Sessions

Agents are ephemeral. They spawn, execute, submit, die.

**Why:** Persistent agents require state management, session recovery, upgrade paths - complexity that doesn't pay off.

*Update: We're adding persistent sessions as an optional feature, but ephemeral is still the default.*

### ❌ Perfect Agent Code

Agents will make mistakes. You review and fix.

**Why:** Trying to make agents perfect means complex validation, testing, rollback - complexity that doesn't pay off. Humans are better reviewers than validators.

### ❌ Zero Configuration

Cairn requires setup: Nix, devenv, LLM, Neovim, tmux.

**Why:** We target power users who already have development environments. Trying to support every editor/OS/workflow means complexity that doesn't pay off.

### ❌ Universal Tool Support

Cairn works best with: Neovim, tmux, jj, Nix.

**Why:** Supporting every editor (VS Code, IntelliJ, Emacs) means lowest-common-denominator features. We pick a stack and go deep.

## Design Goals

Things Cairn DOES prioritize:

### ✅ Composability

Each layer is replaceable:
- Storage: AgentFS → could be git-worktree
- Execution: Monty → could be WASM
- LLM: llm library → pluggable providers
- Editor: Neovim → could be Helix
- VCS: Jujutsu → could be git

Modular architecture from day one.

### ✅ Performance

- Agent spawn: <1s
- Code execution: <5s
- Preview open: <100ms
- Accept/reject: <50ms

Fast enough to feel instant.

### ✅ Safety

- Overlays can't corrupt stable
- Monty can't access filesystem
- Agents can't break your build
- Worst case: Delete overlay, continue

Safe enough to trust.

### ✅ Transparency

- Every agent action is logged
- Every overlay is inspectable
- Every diff is readable
- Every acceptance is auditable

Clear enough to understand.

## The Interaction Model

### Traditional: Sequential

```
Human → Code → AI → Suggestion → Human → Accept → Repeat
       ↑_______________________________________________|
```

One actor at a time. Turns.

### Cairn: Parallel

```
Human → Code ──────────────────────────→ Continues coding
         ↓
        Queue task
         ↓
Agent → Code in overlay ──→ Submit
         ↓                    ↓
Human ← Ghost text ← Review → Accept/Reject
         ↓                    ↓
        Continues coding ←────┘
```

Multiple actors. Simultaneous. Non-blocking.

## Success Metrics

Cairn succeeds if:

1. **Time to review < 30s** - Preview opens fast, diffs are clear
2. **Agent success rate > 70%** - Most submissions are useful
3. **Zero interruptions** - Human never waits for agent
4. **Zero corruption** - Stable layer never breaks
5. **Zero friction** - Accept/reject is one keystroke

## Philosophical Stance

### On AI

AI is not intelligent. It's a **pattern matcher** that generates plausible continuations.

Therefore:
- Don't trust it blindly (isolation)
- Don't expect perfection (review)
- Don't give it control (sandbox)
- Do leverage its strengths (pattern completion)

### On Collaboration

Humans and AI don't "pair program" - that implies equal partnership.

Instead:
- Humans **direct** (set goals)
- AI **executes** (generates code)
- Humans **review** (accept/reject)

Clear hierarchy. Clear roles.

### On Complexity

Simple systems beat complex systems.

Therefore:
- Copy beats merge
- Files beat abstractions
- Overlays beat branches
- Preview beats introspection

When in doubt, simpler.

## Evolution Path

### Phase 1: MVP (Current)

- Single agent at a time
- Full submission accept/reject
- Basic ghost text
- Manual task queue

**Goal:** Prove the concept works.

### Phase 2: Enhanced

- Multiple concurrent agents
- File-level accept/reject
- TMUX preview workspace
- Auto-materialization
- Priority task queue

**Goal:** Production-ready workflow.

### Phase 3: Advanced

- Persistent agent sessions
- Hunk-level accept/reject
- Agent learning from past accepts/rejects
- Multi-repo support
- Remote agents

**Goal:** Power user features.

### Phase 4: Ecosystem

- VS Code plugin (maybe)
- Git backend (in addition to AgentFS)
- Alternative sandboxes (WASM, gVisor)
- Public agent marketplace

**Goal:** Community adoption.

## Conclusion

Cairn is:

- **Not** a copilot (no shared cursor)
- **Not** an autonomous agent (you're in control)
- **Not** a build system (just overlays)

Cairn **is**:

- A workspace manager for AI collaboration
- A safe sandbox for agent execution
- A review interface for agent proposals
- A composable stack for experimentation

The goal: **Make AI agents useful without getting in your way.**

Like a cairn on a hiking trail - helpful markers that don't dictate your path.

---

**Next:** See [SPEC.md](SPEC.md) for technical architecture and [AGENT.md](AGENT.md) for development guidelines.
