"""Unit tests for AgentExecutor.

Tests implement all contracts from ROADMAP-STEP_2.md.
"""

import pytest

from cairn.executor import AgentExecutor


class TestAgentExecutor:
    """Test agent code execution."""

    @pytest.mark.asyncio
    async def test_successful_execution(self):
        """Contract 1: Successful execution returns result."""
        code = """
2 + 2
"""
        executor = AgentExecutor()
        result = await executor.execute(code, {}, "test-agent")

        assert result.success is True
        assert result.return_value == 4
        assert result.error is None

    @pytest.mark.asyncio
    async def test_syntax_error_handling(self):
        """Contract 2: Syntax errors are caught."""
        code = """
def broken(
    pass
"""
        executor = AgentExecutor()
        result = await executor.execute(code, {}, "test-agent")

        assert result.success is False
        assert result.error_type == "syntax"

    @pytest.mark.asyncio
    async def test_runtime_error_handling(self):
        """Contract 3: Runtime errors are caught."""
        code = """
x = undefined_variable
"""
        executor = AgentExecutor()
        result = await executor.execute(code, {}, "test-agent")

        assert result.success is False
        assert result.error_type in ("runtime", "unknown")

    @pytest.mark.asyncio
    async def test_timeout_enforcement(self):
        """Contract 4: Timeout enforced."""
        code = """
while True:
    pass
"""
        executor = AgentExecutor(max_execution_time=1)  # 1 second
        result = await executor.execute(code, {}, "test-agent")

        assert result.success is False
        assert result.error_type == "timeout"

    @pytest.mark.asyncio
    async def test_external_function_calls(self):
        """Contract 6: External functions are callable."""
        code = """
content = read_file("test.txt")
len(content)
"""

        def read_file(path: str) -> str:
            return "hello world"

        executor = AgentExecutor()
        result = await executor.execute(
            code, {"read_file": read_file}, "test-agent"
        )

        assert result.success is True
        assert result.return_value == len("hello world")

    @pytest.mark.asyncio
    async def test_imports_blocked(self):
        """Contract 7: Imports are blocked."""
        code = """
import os
os.getcwd()
"""
        executor = AgentExecutor()
        result = await executor.execute(code, {}, "test-agent")

        assert result.success is False

    @pytest.mark.asyncio
    async def test_file_io_blocked(self):
        """Contract 8: File I/O is blocked."""
        code = """
with open("test.txt", "w") as f:
    f.write("hello")
"""
        executor = AgentExecutor()
        result = await executor.execute(code, {}, "test-agent")

        assert result.success is False

    @pytest.mark.asyncio
    async def test_execution_duration_tracked(self):
        """Test that execution duration is tracked."""
        code = """
2 + 2
"""
        executor = AgentExecutor()
        result = await executor.execute(code, {}, "test-agent")

        assert result.duration_ms > 0

    @pytest.mark.asyncio
    async def test_agent_id_preserved(self):
        """Test that agent ID is preserved in result."""
        code = """
42
"""
        executor = AgentExecutor()
        result = await executor.execute(code, {}, "my-agent-123")

        assert result.agent_id == "my-agent-123"

    def test_validate_code_syntax(self):
        """Test code validation for syntax."""
        executor = AgentExecutor()

        valid_code = "result = 2 + 2"
        is_valid, error = executor.validate_code(valid_code)
        assert is_valid is True
        assert error is None

        invalid_code = "def broken("
        is_valid, error = executor.validate_code(invalid_code)
        assert is_valid is False
        assert error is not None

    @pytest.mark.asyncio
    async def test_multiple_external_functions(self):
        """Test calling multiple external functions."""
        code = """
x = add(2, 3)
y = multiply(x, 4)
y
"""

        def add(a: int, b: int) -> int:
            return a + b

        def multiply(a: int, b: int) -> int:
            return a * b

        executor = AgentExecutor()
        result = await executor.execute(
            code,
            {"add": add, "multiply": multiply},
            "test-agent",
        )

        assert result.success is True
        assert result.return_value == 20  # (2+3) * 4
