# Stage 1: Foundation - Storage & Data Layer

**Goal**: Establish bulletproof storage primitives that everything builds on

**Status**: 🟡 In Progress
**Estimated Duration**: 2-3 weeks
**Dependencies**: None (foundation layer)

---

## Overview

This stage focuses on completing and thoroughly testing the `agentfs-pydantic` library. This library is the foundation of the entire Cairn system, providing type-safe models and a powerful query interface for AgentFS. All subsequent stages depend on this working flawlessly.

The key insight: **AgentFS overlays are the core innovation**. We must prove they work correctly before building anything on top.

---

## Deliverables

### 1. Complete Pydantic Models

**File**: `agentfs-pydantic/src/agentfs_pydantic/models.py`

**Requirements**:
- ✅ `AgentFSOptions` - Validated options for opening AgentFS
  - Must validate either `id` or `path` is provided
  - Must set sensible defaults
- ✅ `FileEntry` - File representation with stats and content
  - Optional stats and content fields
  - Path validation
- ✅ `FileStats` - File metadata (size, mtime, is_file, is_directory)
  - All fields properly typed
  - Datetime handling for mtime
- ✅ `KVEntry` - Key-value store entry
  - Key and value fields
- ✅ `ToolCall` - Function call tracking
  - ID, name, parameters, result, status, timestamps
- ✅ `ToolCallStats` - Aggregate statistics
  - total_calls, successful, failed, avg_duration_ms

**Contracts**:
```python
# Contract 1: AgentFSOptions validation
options = AgentFSOptions(id="my-agent")
assert options.id == "my-agent"

options = AgentFSOptions(path="./data/custom.db")
assert options.path == Path("./data/custom.db")

with pytest.raises(ValidationError):
    AgentFSOptions()  # Must provide either id or path

# Contract 2: FileEntry with optional fields
entry = FileEntry(path="/test.txt")
assert entry.path == "/test.txt"
assert entry.stats is None
assert entry.content is None

entry_full = FileEntry(
    path="/test.txt",
    stats=FileStats(size=100, mtime=datetime.now(), is_file=True, is_directory=False),
    content="hello"
)
assert entry_full.stats.size == 100
assert entry_full.content == "hello"

# Contract 3: ToolCall status validation
call = ToolCall(
    id=1,
    name="read_file",
    parameters={"path": "test.py"},
    result={"content": "..."},
    status="success",
    started_at=datetime.now(),
    completed_at=datetime.now()
)
assert call.status == "success"
```

---

### 2. View Query System

**File**: `agentfs-pydantic/src/agentfs_pydantic/view.py`

**Requirements**:
- ✅ `ViewQuery` - Query specification with filters
  - path_pattern (glob)
  - recursive (bool)
  - include_content (bool)
  - include_stats (bool)
  - regex_pattern (optional)
  - max_size, min_size (optional)
- ✅ `View` - Query execution and results
  - `load()` - Execute query and return FileEntry list
  - `count()` - Efficient counting without loading content
  - `filter()` - Post-query filtering with predicates
  - `with_pattern()`, `with_content()` - Fluent API

**Contracts**:
```python
# Contract 1: Basic query
view = View(agent=agent, query=ViewQuery(path_pattern="*.py", recursive=True))
files = await view.load()
assert all(f.path.endswith(".py") for f in files)

# Contract 2: Content inclusion
view_no_content = View(
    agent=agent,
    query=ViewQuery(path_pattern="*.py", include_content=False)
)
files = await view_no_content.load()
assert all(f.content is None for f in files)

view_with_content = View(
    agent=agent,
    query=ViewQuery(path_pattern="*.py", include_content=True)
)
files = await view_with_content.load()
assert all(f.content is not None for f in files)

# Contract 3: Size filters
view = View(
    agent=agent,
    query=ViewQuery(
        path_pattern="*",
        min_size=1024,  # >= 1KB
        max_size=10240  # <= 10KB
    )
)
files = await view.load()
assert all(1024 <= f.stats.size <= 10240 for f in files)

# Contract 4: Regex pattern
view = View(
    agent=agent,
    query=ViewQuery(
        path_pattern="*",
        regex_pattern=r"^/src/.*\.py$"  # Only /src/*.py
    )
)
files = await view.load()
assert all(f.path.startswith("/src/") and f.path.endswith(".py") for f in files)

# Contract 5: Efficient counting
view = View(agent=agent, query=ViewQuery(path_pattern="*.py"))
count = await view.count()
files = await view.load()
assert count == len(files)

# Contract 6: Fluent API
files = await (
    View(agent=agent)
    .with_pattern("*.json")
    .with_content(True)
    .load()
)
assert all(f.path.endswith(".json") for f in files)
assert all(f.content is not None for f in files)

# Contract 7: Custom filters
view = View(agent=agent, query=ViewQuery(path_pattern="*"))
large_files = await view.filter(lambda f: f.stats and f.stats.size > 1000)
assert all(f.stats.size > 1000 for f in large_files)
```

---

### 3. AgentFS Integration Tests

**File**: `agentfs-pydantic/tests/test_integration.py`

**Requirements**:
Test the actual AgentFS SDK integration, especially overlay semantics.

**Contracts**:
```python
# Contract 1: Overlay read fallthrough
@pytest.mark.asyncio
async def test_overlay_read_fallthrough():
    """Agent reads from stable if file not in overlay"""
    stable = await AgentFS.open(AgentFSOptions(id="test-stable"))
    agent = await AgentFS.open(AgentFSOptions(id="test-agent"))

    # Write to stable
    await stable.fs.write_file("test.txt", b"stable content")

    # Read from agent (should fall through to stable)
    content = await agent.fs.read_file("test.txt")
    assert content == b"stable content"

# Contract 2: Overlay write isolation
@pytest.mark.asyncio
async def test_overlay_write_isolation():
    """Agent writes don't affect stable"""
    stable = await AgentFS.open(AgentFSOptions(id="test-stable"))
    agent = await AgentFS.open(AgentFSOptions(id="test-agent"))

    # Write to stable
    await stable.fs.write_file("test.txt", b"stable content")

    # Write to agent overlay
    await agent.fs.write_file("test.txt", b"agent content")

    # Verify isolation
    stable_content = await stable.fs.read_file("test.txt")
    agent_content = await agent.fs.read_file("test.txt")

    assert stable_content == b"stable content"
    assert agent_content == b"agent content"

# Contract 3: Multiple overlays don't interfere
@pytest.mark.asyncio
async def test_multiple_overlays_isolation():
    """Multiple agents have independent overlays"""
    stable = await AgentFS.open(AgentFSOptions(id="test-stable"))
    agent1 = await AgentFS.open(AgentFSOptions(id="test-agent-1"))
    agent2 = await AgentFS.open(AgentFSOptions(id="test-agent-2"))

    # Write to stable
    await stable.fs.write_file("test.txt", b"stable")

    # Each agent writes different content
    await agent1.fs.write_file("test.txt", b"agent1")
    await agent2.fs.write_file("test.txt", b"agent2")

    # Verify each sees their own version
    assert await stable.fs.read_file("test.txt") == b"stable"
    assert await agent1.fs.read_file("test.txt") == b"agent1"
    assert await agent2.fs.read_file("test.txt") == b"agent2"

# Contract 4: KV store operations
@pytest.mark.asyncio
async def test_kv_store():
    """KV store works correctly"""
    agent = await AgentFS.open(AgentFSOptions(id="test-agent"))

    # Set and get
    await agent.kv.set("key1", "value1")
    value = await agent.kv.get("key1")
    assert value == "value1"

    # List with prefix
    await agent.kv.set("config:theme", "dark")
    await agent.kv.set("config:lang", "en")
    await agent.kv.set("other:data", "xyz")

    entries = await agent.kv.list("config:")
    assert len(entries) == 2
    assert all(e.key.startswith("config:") for e in entries)

    # Delete
    await agent.kv.delete("key1")
    value = await agent.kv.get("key1")
    assert value is None

# Contract 5: View query with real data
@pytest.mark.asyncio
async def test_view_query_integration():
    """View query works with real AgentFS"""
    agent = await AgentFS.open(AgentFSOptions(id="test-agent"))

    # Create test files
    await agent.fs.write_file("main.py", b"print('hello')")
    await agent.fs.write_file("test.py", b"def test(): pass")
    await agent.fs.write_file("README.md", b"# Project")

    # Query Python files
    view = View(
        agent=agent,
        query=ViewQuery(
            path_pattern="*.py",
            recursive=True,
            include_content=True
        )
    )

    files = await view.load()
    assert len(files) == 2
    assert all(f.path.endswith(".py") for f in files)
    assert all(f.content is not None for f in files)
```

---

### 4. Performance Benchmarks

**File**: `agentfs-pydantic/tests/test_performance.py`

**Requirements**:
Ensure operations meet performance targets.

**Performance Contracts**:
```python
# Contract 1: File operations < 10ms
@pytest.mark.benchmark
async def test_file_write_performance():
    """File writes should be fast"""
    agent = await AgentFS.open(AgentFSOptions(id="bench-agent"))

    start = time.time()
    for i in range(100):
        await agent.fs.write_file(f"file_{i}.txt", b"test content")
    duration = time.time() - start

    avg_ms = (duration / 100) * 1000
    assert avg_ms < 10, f"Average write time {avg_ms:.2f}ms exceeds 10ms target"

# Contract 2: Query operations < 50ms
@pytest.mark.benchmark
async def test_view_query_performance():
    """View queries should be fast"""
    agent = await AgentFS.open(AgentFSOptions(id="bench-agent"))

    # Create 1000 files
    for i in range(1000):
        await agent.fs.write_file(f"file_{i}.py", b"# test")

    # Query without content
    start = time.time()
    view = View(agent=agent, query=ViewQuery(path_pattern="*.py", include_content=False))
    files = await view.load()
    duration = (time.time() - start) * 1000

    assert duration < 50, f"Query took {duration:.2f}ms, exceeds 50ms target"
    assert len(files) == 1000

# Contract 3: Large file handling
@pytest.mark.benchmark
async def test_large_file_handling():
    """Can handle files up to 10MB"""
    agent = await AgentFS.open(AgentFSOptions(id="bench-agent"))

    # Create 10MB file
    large_content = b"x" * (10 * 1024 * 1024)

    start = time.time()
    await agent.fs.write_file("large.bin", large_content)
    write_duration = (time.time() - start) * 1000

    start = time.time()
    content = await agent.fs.read_file("large.bin")
    read_duration = (time.time() - start) * 1000

    assert content == large_content
    assert write_duration < 500, f"Large file write took {write_duration:.2f}ms"
    assert read_duration < 500, f"Large file read took {read_duration:.2f}ms"
```

---

## Test Suite Requirements

### Unit Tests (70% of tests)
**File**: `agentfs-pydantic/tests/test_models.py`

- Test all Pydantic model validation
- Test edge cases (empty strings, None values, invalid data)
- Test serialization/deserialization
- Test model_dump() output

### Integration Tests (20% of tests)
**File**: `agentfs-pydantic/tests/test_integration.py`

- Test with real AgentFS SDK
- Test overlay semantics thoroughly
- Test KV store operations
- Test tool call tracking
- Test View query with real data

### Performance Tests (10% of tests)
**File**: `agentfs-pydantic/tests/test_performance.py`

- Benchmark file operations
- Benchmark query operations
- Test with large datasets (1000+ files)
- Test with large files (10MB+)

---

## Exit Criteria

Before proceeding to Stage 2, ALL of the following must be true:

### Code Quality
- [ ] All code in `agentfs-pydantic/src/` is complete
- [ ] Type hints on all functions
- [ ] Docstrings on all public APIs
- [ ] No TODO comments in production code

### Testing
- [ ] 95%+ test coverage (pytest-cov)
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All performance benchmarks met
- [ ] Property-based tests for overlay isolation (hypothesis)

### Performance
- [ ] File operations < 10ms average
- [ ] Query operations < 50ms for 1000 files
- [ ] View.load() handles 10,000+ files efficiently
- [ ] Memory usage reasonable (< 100MB for 1000 files in memory)

### Documentation
- [ ] README.md complete with examples
- [ ] API documentation generated (mkdocs or similar)
- [ ] All contracts documented in docstrings
- [ ] Examples in `examples/` directory work

### Publishing
- [ ] Package builds successfully (`uv build`)
- [ ] Package installable via pip
- [ ] Published to PyPI (or test PyPI)
- [ ] Version number set (0.1.0)

### Integration
- [ ] Works with latest agentfs-sdk (0.6.0+)
- [ ] Compatible with Python 3.11, 3.12, 3.13
- [ ] No dependency conflicts

---

## Key Risks & Mitigations

### Risk 1: Overlay semantics don't work as expected
**Impact**: High - entire system depends on this
**Mitigation**: Extensive integration tests with real AgentFS SDK
**Validation**: Write tests FIRST, then implement

### Risk 2: Performance doesn't meet targets
**Impact**: Medium - will affect user experience
**Mitigation**: Profile early, optimize query patterns
**Validation**: Run benchmarks continuously, don't wait until end

### Risk 3: AgentFS SDK API changes
**Impact**: Medium - need to adapt
**Mitigation**: Pin to specific SDK version, monitor releases
**Validation**: Test against multiple SDK versions

---

## Development Workflow

### 1. Test-Driven Development
Write tests first, then implement:

```bash
# Write test
vim agentfs-pydantic/tests/test_models.py

# Run test (should fail)
uv run pytest tests/test_models.py -v

# Implement feature
vim agentfs-pydantic/src/agentfs_pydantic/models.py

# Run test (should pass)
uv run pytest tests/test_models.py -v
```

### 2. Continuous Integration
Every commit should:
- Run all tests
- Check test coverage
- Run type checker (mypy)
- Run linter (ruff)

### 3. Documentation Updates
As you implement, update:
- Docstrings in code
- README.md with examples
- SKILL-AGENTFS.md with patterns

---

## Success Metrics

At the end of Stage 1, we should be able to:

1. **Install the library**: `uv add agentfs-pydantic`
2. **Open an agent**: `agent = await AgentFS.open(AgentFSOptions(id="test"))`
3. **Query files**: `files = await View(agent).with_pattern("*.py").load()`
4. **Verify overlay isolation**: Write to agent, stable unchanged
5. **Publish independently**: Library usable outside Cairn

**If all exit criteria are met, proceed to Stage 2.**
