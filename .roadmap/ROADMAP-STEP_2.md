# Stage 2: Execution Layer - Monty Sandbox

**Goal**: Safe, reliable agent code execution with proper resource limits

**Status**: ⚪ Not Started
**Estimated Duration**: 2-3 weeks
**Dependencies**: Stage 1 (agentfs-pydantic complete)

---

## Overview

This stage implements the execution layer where agent code runs safely in a Monty sandbox. Monty is a minimal Python interpreter written in Rust that prevents agents from accessing the filesystem, network, or any system resources except through explicitly provided external functions.

The key challenge: **Agents must be powerful enough to be useful, but restricted enough to be safe.**

---

## Deliverables

### 1. External Function Interface

**File**: `cairn/external_functions.py`

**Requirements**:
Define all external functions that agents can call:

```python
from typing import Protocol, Any

class ExternalFunctions(Protocol):
    """Protocol defining external functions available to agents"""

    async def read_file(self, path: str) -> str:
        """Read file from agent overlay (falls through to stable)"""
        ...

    async def write_file(self, path: str, content: str) -> bool:
        """Write file to agent overlay only"""
        ...

    async def list_dir(self, path: str) -> list[str]:
        """List directory contents"""
        ...

    async def file_exists(self, path: str) -> bool:
        """Check if file exists"""
        ...

    async def search_files(self, pattern: str) -> list[str]:
        """Find files matching glob pattern (uses ripgrep or find)"""
        ...

    async def search_content(self, pattern: str, path: str = ".") -> list[dict[str, Any]]:
        """Search file contents (uses ripgrep)"""
        ...

    async def ask_llm(self, prompt: str, context: str = "") -> str:
        """Query LLM for assistance"""
        ...

    async def submit_result(self, summary: str, changed_files: list[str]) -> bool:
        """Submit agent results for review"""
        ...

    async def log(self, message: str) -> bool:
        """Log debug message"""
        ...
```

**Contracts**:
```python
# Contract 1: read_file falls through to stable
async def test_read_file_fallthrough():
    stable = await AgentFS.open(AgentFSOptions(id="stable"))
    agent = await AgentFS.open(AgentFSOptions(id="agent"))

    await stable.fs.write_file("test.txt", b"stable content")

    ext_funcs = create_external_functions(agent, stable)
    content = await ext_funcs.read_file("test.txt")

    assert content == "stable content"

# Contract 2: write_file only to overlay
async def test_write_file_isolation():
    stable = await AgentFS.open(AgentFSOptions(id="stable"))
    agent = await AgentFS.open(AgentFSOptions(id="agent"))

    ext_funcs = create_external_functions(agent, stable)
    result = await ext_funcs.write_file("new.txt", "agent content")

    assert result is True
    assert await agent.fs.read_file("new.txt") == b"agent content"

    # Stable should not have the file
    with pytest.raises(FileNotFoundError):
        await stable.fs.read_file("new.txt")

# Contract 3: search_files uses glob patterns
async def test_search_files():
    agent = await AgentFS.open(AgentFSOptions(id="agent"))
    await agent.fs.write_file("main.py", b"")
    await agent.fs.write_file("test.py", b"")
    await agent.fs.write_file("README.md", b"")

    ext_funcs = create_external_functions(agent, stable)
    py_files = await ext_funcs.search_files("*.py")

    assert len(py_files) == 2
    assert "main.py" in py_files
    assert "test.py" in py_files
    assert "README.md" not in py_files

# Contract 4: search_content returns structured results
async def test_search_content():
    agent = await AgentFS.open(AgentFSOptions(id="agent"))
    await agent.fs.write_file("main.py", b"def hello():\n    print('hello')")

    ext_funcs = create_external_functions(agent, stable)
    results = await ext_funcs.search_content("hello", ".")

    assert len(results) > 0
    assert results[0]["file"] == "main.py"
    assert "line" in results[0]
    assert "text" in results[0]

# Contract 5: ask_llm integrates with LLM provider
async def test_ask_llm():
    ext_funcs = create_external_functions(agent, stable, llm_provider=mock_llm)
    response = await ext_funcs.ask_llm("What is 2+2?", "")

    assert isinstance(response, str)
    assert len(response) > 0

# Contract 6: submit_result stores in KV
async def test_submit_result():
    agent = await AgentFS.open(AgentFSOptions(id="agent"))
    ext_funcs = create_external_functions(agent, stable)

    result = await ext_funcs.submit_result(
        "Added docstrings",
        ["main.py", "utils.py"]
    )

    assert result is True

    # Verify stored in KV
    submission_str = await agent.kv.get("submission")
    submission = json.loads(submission_str)
    assert submission["summary"] == "Added docstrings"
    assert submission["changed_files"] == ["main.py", "utils.py"]
```

---

### 2. Monty Integration

**File**: `cairn/executor.py`

**Requirements**:
Wrap Monty sandbox execution with proper error handling and resource limits.

```python
import pydantic_monty
from typing import Any

class AgentExecutor:
    """Executes agent code in Monty sandbox"""

    def __init__(
        self,
        max_execution_time: int = 60,
        max_memory_bytes: int = 100 * 1024 * 1024,
        max_stack_depth: int = 1000,
    ):
        self.max_execution_time = max_execution_time
        self.max_memory_bytes = max_memory_bytes
        self.max_stack_depth = max_stack_depth

    async def execute(
        self,
        code: str,
        external_functions: dict[str, Any],
        agent_id: str,
    ) -> ExecutionResult:
        """Execute agent code with external functions"""
        ...
```

**Contracts**:
```python
# Contract 1: Successful execution returns result
async def test_successful_execution():
    code = """
result = 2 + 2
"""
    executor = AgentExecutor()
    result = await executor.execute(code, {}, "test-agent")

    assert result.success is True
    assert result.return_value == 4
    assert result.error is None

# Contract 2: Syntax errors are caught
async def test_syntax_error_handling():
    code = """
def broken(
    pass
"""
    executor = AgentExecutor()
    result = await executor.execute(code, {}, "test-agent")

    assert result.success is False
    assert "syntax error" in result.error.lower()

# Contract 3: Runtime errors are caught
async def test_runtime_error_handling():
    code = """
undefined_variable
"""
    executor = AgentExecutor()
    result = await executor.execute(code, {}, "test-agent")

    assert result.success is False
    assert "name" in result.error.lower()

# Contract 4: Timeout enforced
async def test_timeout_enforcement():
    code = """
while True:
    pass
"""
    executor = AgentExecutor(max_execution_time=1)  # 1 second
    result = await executor.execute(code, {}, "test-agent")

    assert result.success is False
    assert "timeout" in result.error.lower()

# Contract 5: Memory limit enforced
async def test_memory_limit_enforcement():
    code = """
big_list = []
for i in range(10000000):
    big_list.append([0] * 10000)
"""
    executor = AgentExecutor(max_memory_bytes=1024 * 1024)  # 1MB
    result = await executor.execute(code, {}, "test-agent")

    assert result.success is False
    assert "memory" in result.error.lower()

# Contract 6: External functions are callable
async def test_external_function_calls():
    code = """
content = read_file("test.txt")
result = len(content)
"""
    async def read_file(path: str) -> str:
        return "hello world"

    executor = AgentExecutor()
    result = await executor.execute(
        code,
        {"read_file": read_file},
        "test-agent"
    )

    assert result.success is True
    assert result.return_value == len("hello world")

# Contract 7: Imports are blocked
async def test_imports_blocked():
    code = """
import os
"""
    executor = AgentExecutor()
    result = await executor.execute(code, {}, "test-agent")

    assert result.success is False
    assert "import" in result.error.lower()

# Contract 8: File I/O is blocked
async def test_file_io_blocked():
    code = """
with open("test.txt", "w") as f:
    f.write("hello")
"""
    executor = AgentExecutor()
    result = await executor.execute(code, {}, "test-agent")

    assert result.success is False
    # Should fail because open() is not available
```

---

### 3. LLM Code Generation

**File**: `cairn/code_generator.py`

**Requirements**:
Generate valid Python code for agent tasks using LLM.

```python
import llm

class CodeGenerator:
    """Generates agent code using LLM"""

    PROMPT_TEMPLATE = """Write a short Python script to accomplish this task:
{task}

Available functions (the ONLY things you can call):
- read_file(path: str) -> str
- write_file(path: str, content: str) -> bool
- list_dir(path: str) -> list[str]
- file_exists(path: str) -> bool
- search_files(pattern: str) -> list[str]
- search_content(pattern: str, path: str = ".") -> list[dict]
- ask_llm(prompt: str, context: str = "") -> str
- submit_result(summary: str, changed_files: list[str]) -> bool
- log(message: str) -> bool

Constraints:
- You CANNOT: import anything, define classes, use open(), use print()
- Write simple procedural Python: variables, functions, loops, conditionals only
- Always call submit_result() at the end with summary and list of changed files
- Use log() to debug

Respond with ONLY the Python code. No markdown, no explanation.
"""

    def __init__(self, model: str | None = None):
        self.model = llm.get_model(model) if model else llm.get_default_model()

    async def generate(self, task: str) -> str:
        """Generate Python code for task"""
        ...

    def extract_code(self, response: str) -> str:
        """Extract code from LLM response (remove markdown fences)"""
        ...
```

**Contracts**:
```python
# Contract 1: Generate valid Python code
async def test_generate_valid_code():
    generator = CodeGenerator(model="gpt-4")
    code = await generator.generate("Add docstrings to functions")

    assert isinstance(code, str)
    assert len(code) > 0
    assert "def " in code or "=" in code  # Has some code

# Contract 2: Extract code from markdown
def test_extract_code_from_markdown():
    response = """```python
result = 2 + 2
```"""
    generator = CodeGenerator()
    code = generator.extract_code(response)

    assert code == "result = 2 + 2"

# Contract 3: Extract code without markdown
def test_extract_code_plain():
    response = "result = 2 + 2"
    generator = CodeGenerator()
    code = generator.extract_code(response)

    assert code == "result = 2 + 2"

# Contract 4: Generated code is executable
async def test_generated_code_executable():
    generator = CodeGenerator(model="gpt-4")
    task = "List all Python files and count their lines"
    code = await generator.generate(task)

    # Should be valid Python
    compile(code, "<string>", "exec")  # Will raise if invalid

# Contract 5: Generated code uses external functions
async def test_generated_code_uses_external_functions():
    generator = CodeGenerator(model="gpt-4")
    task = "Read all .py files and add a comment"
    code = await generator.generate(task)

    # Should use external functions
    assert "read_file" in code or "search_files" in code
    assert "write_file" in code
    assert "submit_result" in code
```

---

### 4. Error Handling & Retry Logic

**File**: `cairn/retry.py`

**Requirements**:
Implement robust retry logic for LLM generation and execution failures.

```python
class RetryStrategy:
    """Retry failed operations with backoff"""

    def __init__(self, max_attempts: int = 3):
        self.max_attempts = max_attempts

    async def with_retry(
        self,
        operation: Callable[[], Awaitable[T]],
        error_handler: Callable[[Exception], Awaitable[None]] | None = None,
    ) -> T:
        """Execute operation with retry"""
        ...
```

**Contracts**:
```python
# Contract 1: Retry on failure
async def test_retry_on_failure():
    attempts = 0

    async def failing_operation():
        nonlocal attempts
        attempts += 1
        if attempts < 3:
            raise ValueError("Not yet")
        return "success"

    retry = RetryStrategy(max_attempts=3)
    result = await retry.with_retry(failing_operation)

    assert result == "success"
    assert attempts == 3

# Contract 2: Give up after max attempts
async def test_give_up_after_max_attempts():
    async def always_fails():
        raise ValueError("Always fails")

    retry = RetryStrategy(max_attempts=3)

    with pytest.raises(ValueError):
        await retry.with_retry(always_fails)

# Contract 3: Error handler called on each failure
async def test_error_handler_called():
    errors = []

    async def failing_operation():
        raise ValueError("Failure")

    async def error_handler(e: Exception):
        errors.append(str(e))

    retry = RetryStrategy(max_attempts=3)

    with pytest.raises(ValueError):
        await retry.with_retry(failing_operation, error_handler)

    assert len(errors) == 3
```

---

## Test Suite Requirements

### Unit Tests (70% of tests)
**Files**: `tests/cairn/test_external_functions.py`, `tests/cairn/test_code_generator.py`

- Test each external function in isolation
- Test code extraction logic
- Test retry logic
- Mock LLM responses
- Mock AgentFS calls

### Integration Tests (20% of tests)
**File**: `tests/cairn/test_executor_integration.py`

- Test full execution pipeline: generate → execute → result
- Test with real AgentFS (not mocked)
- Test external functions called from within Monty
- Test error propagation
- Test resource limits

### End-to-End Tests (10% of tests)
**File**: `tests/cairn/test_e2e_execution.py`

- Test with real LLM (OpenAI, Anthropic, or local)
- Test real agent tasks: "Add docstrings", "Fix TODOs", etc.
- Verify submissions stored correctly
- Verify overlays remain isolated

---

## Exit Criteria

### Code Quality
- [ ] All external functions implemented with error handling
- [ ] Monty executor handles all error types gracefully
- [ ] LLM code generator has prompt template
- [ ] Retry logic configurable and tested

### Security
- [ ] Agent code CANNOT access filesystem (except via functions)
- [ ] Agent code CANNOT access network (except via functions)
- [ ] Agent code CANNOT import stdlib or third-party modules
- [ ] Agent code CANNOT bypass sandbox (proven via security tests)
- [ ] External functions validate inputs (path traversal, size limits)

### Testing
- [ ] 90%+ test coverage
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Security tests prove sandbox works
- [ ] E2E test with real LLM passes

### Performance
- [ ] Code generation < 5s average
- [ ] Code execution < 10s average (for simple tasks)
- [ ] Resource limits enforced reliably
- [ ] No memory leaks during execution

### Documentation
- [ ] SKILL-MONTY.md updated with patterns
- [ ] External function documentation complete
- [ ] Example agent code in `examples/`
- [ ] Security considerations documented

---

## Key Risks & Mitigations

### Risk 1: LLM generates invalid code
**Impact**: High - agents won't work
**Mitigation**: Retry with error context, validate syntax before execution
**Validation**: Track generation success rate, aim for 80%+

### Risk 2: Sandbox escape
**Impact**: Critical - security vulnerability
**Mitigation**: Extensive security testing, use Monty's built-in restrictions
**Validation**: Red team testing, attempt escapes

### Risk 3: Resource exhaustion
**Impact**: Medium - system instability
**Mitigation**: Enforce limits strictly, monitor resource usage
**Validation**: Stress tests with malicious code

---

## Success Metrics

At the end of Stage 2, we should be able to:

1. **Generate agent code**: `code = await generator.generate("Add docstrings")`
2. **Execute safely**: `result = await executor.execute(code, ext_funcs, "agent-1")`
3. **Verify isolation**: Agent cannot access filesystem or network
4. **Handle errors**: Syntax errors, timeouts, memory limits all handled gracefully
5. **LLM success rate**: 80%+ of generated code is valid and executable

**If all exit criteria are met, proceed to Stage 3.**
