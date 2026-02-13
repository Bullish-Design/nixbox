# SKILL: Working with Monty Sandbox

This guide covers using the Monty sandboxed Python interpreter for safe agent code execution in Cairn.

## Overview

**Monty** is a minimal Python interpreter written in Rust that runs untrusted agent code safely. It provides:

- No filesystem access (except via external functions)
- No network access (except via external functions)
- No imports (stdlib or third-party)
- Resource limits (time, memory, stack depth)
- Type checking support

## Installation

Monty is installed via Python:

```bash
uv add pydantic-monty
```

Or in `pyproject.toml`:

```toml
[project]
dependencies = [
    "pydantic-monty>=0.1.0",
]
```

## Basic Usage

### Running Code

```python
import pydantic_monty

code = """
def hello(name: str) -> str:
    return f"Hello, {name}!"

result = hello("World")
"""

# Create Monty instance
m = pydantic_monty.Monty(
    code,
    inputs=[],  # No CLI inputs for Cairn
    external_functions=[],  # No external functions yet
    script_name="agent.py"
)

# Run synchronously
result = pydantic_monty.run_monty(m)
print(result)  # "Hello, World!"

# Or run async
result = await pydantic_monty.run_monty_async(m)
```

### External Functions

External functions are the ONLY way agents can interact with the host:

```python
code = """
content = read_file("main.py")
print(f"File has {len(content)} characters")
"""

async def read_file(path: str) -> str:
    """Read file from AgentFS"""
    return await agent_fs.fs.read_file(path).decode()

m = pydantic_monty.Monty(
    code,
    inputs=[],
    external_functions=["read_file"],  # Declare function names
    script_name="agent.py"
)

# Provide implementations
result = await pydantic_monty.run_monty_async(
    m,
    external_functions={"read_file": read_file}
)
```

## Cairn External Functions

### Required Functions

All Cairn agents have access to these functions:

```python
def read_file(path: str) -> str:
    """Read file from agent overlay (falls through to stable)"""

def write_file(path: str, content: str) -> bool:
    """Write file to agent overlay only"""

def list_dir(path: str) -> list[str]:
    """List directory contents"""

def file_exists(path: str) -> bool:
    """Check if file exists"""

def search_files(pattern: str) -> list[str]:
    """Find files matching glob pattern"""

def search_content(pattern: str, path: str = ".") -> list[dict]:
    """Search file contents (uses ripgrep)"""

def ask_llm(prompt: str, context: str = "") -> str:
    """Query LLM for assistance"""

def submit_result(summary: str, changed_files: list[str]) -> bool:
    """Submit agent results for review"""

def log(message: str) -> bool:
    """Log debug message"""
```

### Implementation Pattern

```python
class CairnOrchestrator:
    def create_external_functions(self, agent_id: str, agent_fs: AgentFS) -> dict:
        """Create external functions for Monty"""

        async def read_file(path: str) -> str:
            try:
                content = await agent_fs.fs.read_file(path)
                return content.decode()
            except FileNotFoundError:
                # Fall through to stable
                content = await self.stable.fs.read_file(path)
                return content.decode()

        async def write_file(path: str, content: str) -> bool:
            await agent_fs.fs.write_file(path, content.encode())
            return True

        async def ask_llm(prompt: str, context: str = "") -> str:
            return await self.llm.generate(prompt, context)

        async def submit_result(summary: str, changed_files: list[str]) -> bool:
            submission = {
                "summary": summary,
                "changed_files": changed_files,
                "submitted_at": time.time()
            }
            await agent_fs.kv.set("submission", json.dumps(submission))
            return True

        async def log(message: str) -> bool:
            print(f"[{agent_id}] {message}")
            return True

        return {
            "read_file": read_file,
            "write_file": write_file,
            "ask_llm": ask_llm,
            "submit_result": submit_result,
            "log": log,
        }
```

## Agent Code Patterns

### Simple Task

```python
# Agent task: "Add docstrings to functions"

# Generated code:
files = search_files("*.py")

for file_path in files:
    content = read_file(file_path)

    if "def " in content and '"""' not in content:
        new_content = ask_llm(
            "Add docstrings to all functions",
            content
        )
        write_file(file_path, new_content)
        log(f"Added docstrings to {file_path}")

submit_result("Added docstrings", files)
```

### Iterative Processing

```python
# Agent task: "Fix TODO comments"

todos_found = []

# Find all TODOs
files = search_files("*.py")
for file in files:
    content = read_file(file)
    if "TODO" in content:
        todos_found.append(file)

# Process each file
for file in todos_found:
    content = read_file(file)

    # Extract TODO lines
    todo_lines = [line for line in content.split("\n") if "TODO" in line]

    # Ask LLM to implement
    prompt = f"Implement these TODOs:\n" + "\n".join(todo_lines)
    new_content = ask_llm(prompt, content)

    write_file(file, new_content)
    log(f"Fixed TODOs in {file}")

submit_result(f"Fixed {len(todos_found)} TODO items", todos_found)
```

### Using LLM for Analysis

```python
# Agent task: "Find and fix potential bugs"

files = search_files("*.py")
bugs_fixed = []

for file in files:
    content = read_file(file)

    # Ask LLM to analyze
    analysis = ask_llm(
        "Identify potential bugs or issues in this code",
        content
    )

    if "bug" in analysis.lower() or "issue" in analysis.lower():
        # Ask LLM to fix
        fixed = ask_llm(
            "Fix the issues you identified",
            content
        )

        write_file(file, fixed)
        bugs_fixed.append(file)
        log(f"Fixed bugs in {file}")

submit_result(f"Fixed bugs in {len(bugs_fixed)} files", bugs_fixed)
```

## Code Generation

### Prompt Template

```python
AGENT_CODE_PROMPT = """Write a short Python script to accomplish this task:
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
```

### Using with LLM

```python
from llm import get_default_model

async def generate_agent_code(task: str) -> str:
    """Generate Python code for agent task"""
    model = get_default_model()

    prompt = AGENT_CODE_PROMPT.format(task=task)
    response = model.prompt(prompt)

    return extract_code(response.text())

def extract_code(response: str) -> str:
    """Extract code from LLM response"""
    lines = response.strip().split("\n")

    # Remove markdown fences if present
    if lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].startswith("```"):
        lines = lines[:-1]

    return "\n".join(lines)
```

## Resource Limits

### Setting Limits

```python
m = pydantic_monty.Monty(
    code,
    inputs=[],
    external_functions=ext_funcs,
    script_name="agent.py",

    # Resource limits
    max_execution_time=60,  # 60 second timeout
    max_memory_bytes=100 * 1024 * 1024,  # 100MB
    max_stack_depth=1000,  # 1000 stack frames
)
```

### Handling Timeout

```python
try:
    result = await pydantic_monty.run_monty_async(m, external_functions=funcs)
except pydantic_monty.TimeoutError:
    # Agent took too long
    await agent_fs.kv.set("error", "Execution timeout (>60s)")
    await trash_agent(agent_id)
```

### Handling Memory Limit

```python
try:
    result = await pydantic_monty.run_monty_async(m, external_functions=funcs)
except pydantic_monty.MemoryError:
    # Agent used too much memory
    await agent_fs.kv.set("error", "Memory limit exceeded (>100MB)")
    await trash_agent(agent_id)
```

## Type Checking

### Enable Type Checking

```python
# Type stubs for external functions
type_stubs = """
def read_file(path: str) -> str: ...
def write_file(path: str, content: str) -> bool: ...
def ask_llm(prompt: str, context: str = "") -> str: ...
def submit_result(summary: str, changed_files: list[str]) -> bool: ...
"""

m = pydantic_monty.Monty(
    code,
    inputs=[],
    external_functions=["read_file", "write_file", "ask_llm", "submit_result"],
    script_name="agent.py",
    type_check=True,  # Enable type checking
    type_check_stubs=type_stubs  # Provide stubs
)

# Type errors will be raised during construction
```

### Type Error Handling

```python
try:
    m = pydantic_monty.Monty(
        code,
        type_check=True,
        type_check_stubs=stubs
    )
except pydantic_monty.TypeCheckError as e:
    # Code has type errors
    print(f"Type error: {e}")

    # Ask LLM to fix
    fixed_code = await llm.generate(
        f"Fix these type errors:\n{e}\n\nCode:\n{code}"
    )

    # Retry
    m = pydantic_monty.Monty(fixed_code, type_check=True, type_check_stubs=stubs)
```

## Error Handling

### Common Errors

```python
try:
    result = await pydantic_monty.run_monty_async(m, external_functions=funcs)

except pydantic_monty.SyntaxError as e:
    # Invalid Python syntax
    await agent_fs.kv.set("error", f"Syntax error: {e}")

except pydantic_monty.NameError as e:
    # Undefined variable or function
    await agent_fs.kv.set("error", f"Name error: {e}")

except pydantic_monty.ImportError as e:
    # Attempted to import (not allowed)
    await agent_fs.kv.set("error", f"Import not allowed: {e}")

except pydantic_monty.TimeoutError:
    await agent_fs.kv.set("error", "Execution timeout")

except pydantic_monty.MemoryError:
    await agent_fs.kv.set("error", "Memory limit exceeded")

except Exception as e:
    # Catch-all for other errors
    await agent_fs.kv.set("error", f"Runtime error: {e}")
```

### Retry Logic

```python
MAX_RETRIES = 3

for attempt in range(MAX_RETRIES):
    try:
        code = await generate_agent_code(task)
        m = pydantic_monty.Monty(code, ...)
        result = await pydantic_monty.run_monty_async(m, ...)
        break  # Success

    except pydantic_monty.SyntaxError as e:
        if attempt < MAX_RETRIES - 1:
            # Ask LLM to fix syntax error
            code = await llm.generate(
                f"Fix this syntax error:\n{e}\n\nCode:\n{code}"
            )
        else:
            raise  # Give up after max retries
```

## Testing

### Unit Tests

```python
import pytest
import pydantic_monty

@pytest.mark.asyncio
async def test_simple_execution():
    """Test basic code execution"""
    code = """
result = 2 + 2
"""

    m = pydantic_monty.Monty(code)
    result = await pydantic_monty.run_monty_async(m)
    assert result == 4

@pytest.mark.asyncio
async def test_external_function():
    """Test external function calls"""
    code = """
data = fetch("https://example.com")
result = len(data)
"""

    async def fetch(url: str) -> str:
        return "mock data"

    m = pydantic_monty.Monty(
        code,
        external_functions=["fetch"]
    )

    result = await pydantic_monty.run_monty_async(
        m,
        external_functions={"fetch": fetch}
    )

    assert result == len("mock data")
```

### Integration Tests

```python
@pytest.mark.asyncio
async def test_full_agent_workflow():
    """Test complete agent code generation and execution"""

    # Generate code
    task = "Add docstrings to functions"
    code = await generate_agent_code(task)

    # Setup external functions
    agent_fs = await AgentFS.open(AgentFSOptions(id="test-agent"))
    ext_funcs = create_external_functions("test-agent", agent_fs)

    # Execute
    m = pydantic_monty.Monty(
        code,
        external_functions=list(ext_funcs.keys())
    )

    result = await pydantic_monty.run_monty_async(m, external_functions=ext_funcs)

    # Verify submission
    submission = await agent_fs.kv.get("submission")
    assert submission is not None
```

## Security Considerations

### What Monty Prevents

✅ File access (except via external functions)
✅ Network access (except via external functions)
✅ Subprocess execution
✅ Environment variable access
✅ Arbitrary imports
✅ Code injection via eval/exec

### What You Must Handle

⚠️ Validate paths in external functions
⚠️ Sanitize LLM input/output
⚠️ Rate limit external function calls
⚠️ Check file size before reading
⚠️ Timeout long-running operations

### Example: Safe External Functions

```python
def create_safe_external_functions(agent_fs: AgentFS) -> dict:
    """Create external functions with safety checks"""

    async def read_file(path: str) -> str:
        # Validate path
        if ".." in path or path.startswith("/"):
            raise ValueError("Invalid path")

        # Check file size
        stat = await agent_fs.fs.stat(path)
        if stat.size > 10 * 1024 * 1024:  # 10MB limit
            raise ValueError("File too large")

        content = await agent_fs.fs.read_file(path)
        return content.decode()

    async def write_file(path: str, content: str) -> bool:
        # Validate path
        if ".." in path or path.startswith("/"):
            raise ValueError("Invalid path")

        # Check content size
        if len(content) > 10 * 1024 * 1024:  # 10MB limit
            raise ValueError("Content too large")

        await agent_fs.fs.write_file(path, content.encode())
        return True

    return {
        "read_file": read_file,
        "write_file": write_file,
    }
```

## Debugging

### Enable Debug Output

```python
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("pydantic_monty")

# Monty will log operations
result = await pydantic_monty.run_monty_async(m, external_functions=funcs)
```

### Inspect Agent Code

```python
# Store generated code for inspection
await agent_fs.kv.set("generated_code", code)

# Later, retrieve and inspect
code = await agent_fs.kv.get("generated_code")
print(code)
```

### Log External Function Calls

```python
def create_logged_external_functions(agent_id: str, agent_fs: AgentFS) -> dict:
    """Create external functions with logging"""

    async def read_file(path: str) -> str:
        print(f"[{agent_id}] read_file({path})")
        content = await agent_fs.fs.read_file(path)
        return content.decode()

    async def write_file(path: str, content: str) -> bool:
        print(f"[{agent_id}] write_file({path}, {len(content)} bytes)")
        await agent_fs.fs.write_file(path, content.encode())
        return True

    return {
        "read_file": read_file,
        "write_file": write_file,
    }
```

## Performance Tips

### Minimize External Function Calls

```python
# ❌ Slow: Many small calls
for i in range(100):
    content = read_file(f"file_{i}.txt")
    process(content)

# ✅ Fast: Batch if possible
files = list_dir(".")
for file in files:
    content = read_file(file)
    process(content)
```

### Cache LLM Responses

```python
llm_cache = {}

async def ask_llm(prompt: str, context: str = "") -> str:
    cache_key = f"{prompt}:{context}"

    if cache_key in llm_cache:
        return llm_cache[cache_key]

    response = await llm.generate(prompt, context)
    llm_cache[cache_key] = response
    return response
```

## References

- [Monty Documentation](https://github.com/pydantic/monty)
- [SPEC.md](../../SPEC.md) - Execution layer architecture
- [SKILL-AGENTFS.md](SKILL-AGENTFS.md) - Storage layer

## Cairn Implementation (Step 2 Complete)

The Cairn execution layer has been implemented in the `cairn/` directory:

### Available Modules

```python
from cairn import (
    AgentExecutor,
    CodeGenerator,
    ExecutionResult,
    ExternalFunctions,
    RetryStrategy,
    create_external_functions,
)
```

### Using the Executor

```python
from cairn.executor import AgentExecutor
from cairn.external_functions import create_external_functions

# Setup external functions
ext_funcs = create_external_functions(
    agent_id="my-agent",
    agent_fs=agent_fs,
    stable_fs=stable_fs,
    llm_provider=llm_provider
)

# Execute agent code
executor = AgentExecutor(
    max_execution_time=60,
    max_memory_bytes=100 * 1024 * 1024,
    max_recursion_depth=1000
)

result = await executor.execute(
    code=agent_code,
    external_functions=ext_funcs,
    agent_id="my-agent"
)

if result.success:
    print(f"Success! Result: {result.return_value}")
else:
    print(f"Failed: {result.error} ({result.error_type})")
```

### Generating Agent Code

```python
from cairn.code_generator import CodeGenerator

generator = CodeGenerator(model="gpt-4")

# Generate code for task
code = await generator.generate("Add docstrings to all functions")

# Validate code
is_valid, error = generator.validate_code(code)
if not is_valid:
    print(f"Validation error: {error}")
```

### Using Retry Logic

```python
from cairn.retry import CodeGenerationRetry

# Create retry strategy
retry = CodeGenerationRetry(
    max_attempts=3,
    code_generator=generator
)

# Generate with retry on validation failures
code = await retry.generate_with_retry(
    task="Add type hints",
    validator=executor.validate_code
)
```

### Example Agent Code

See `examples/cairn/` for complete examples:
- `add_docstrings.py` - Add docstrings to functions
- `fix_todos.py` - Implement TODO comments
- `add_type_hints.py` - Add type hints to functions

## See Also

- [SKILL-AGENTFS.md](SKILL-AGENTFS.md) - For implementing external functions
- [SKILL-JJ.md](SKILL-JJ.md) - For VCS integration
- [../examples/cairn/](../../examples/cairn/) - Example agent code
- [../cairn/](../../cairn/) - Cairn execution layer implementation
