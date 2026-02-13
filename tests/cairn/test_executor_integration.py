"""Integration tests for Cairn execution layer.

Tests full pipeline: generate → execute → result
"""

import pytest
from agentfs_sdk import AgentFS
from agentfs_pydantic import AgentFSOptions

from cairn.code_generator import CodeGenerator
from cairn.executor import AgentExecutor
from cairn.external_functions import create_external_functions


class TestExecutorIntegration:
    """Integration tests for agent execution."""

    @pytest.mark.asyncio
    async def test_full_execution_pipeline(self, stable_fs, agent_fs):
        """Test complete execution: external functions + code execution."""
        # Setup: Create file in stable
        await stable_fs.fs.write_file("test.txt", b"Hello, World!")

        # Create external functions
        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        # Agent code that uses external functions
        code = """
# Read file from stable
content = read_file("test.txt")

# Modify and write to overlay
new_content = content.upper()
write_file("output.txt", new_content)

# Submit result
submit_result("Processed file", ["output.txt"])
result = "success"
"""

        # Execute
        executor = AgentExecutor()
        result = await executor.execute(code, ext_funcs, "test-agent")

        # Verify
        assert result.success is True
        assert result.return_value == "success"

        # Check that file was written to overlay
        output = await agent_fs.fs.read_file("output.txt")
        assert output == b"HELLO, WORLD!"

        # Check that stable is unchanged
        with pytest.raises(FileNotFoundError):
            await stable_fs.fs.read_file("output.txt")

    @pytest.mark.asyncio
    async def test_external_function_error_propagation(
        self, stable_fs, agent_fs
    ):
        """Test that errors in external functions are caught."""
        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        # Code that tries to read non-existent file
        code = """
try:
    content = read_file("missing.txt")
    result = "should not reach here"
except FileNotFoundError:
    result = "caught error"

submit_result("Done", [])
"""

        executor = AgentExecutor()
        result = await executor.execute(code, ext_funcs, "test-agent")

        assert result.success is True
        assert result.return_value == "caught error"

    @pytest.mark.asyncio
    async def test_multiple_file_operations(self, stable_fs, agent_fs):
        """Test agent performing multiple file operations."""
        # Setup initial files
        await stable_fs.fs.write_file("file1.txt", b"Content 1")
        await stable_fs.fs.write_file("file2.txt", b"Content 2")

        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        code = """
# Read multiple files
content1 = read_file("file1.txt")
content2 = read_file("file2.txt")

# Combine and write
combined = content1 + "\\n" + content2
write_file("combined.txt", combined)

# List files
files = search_files("*.txt")

submit_result("Combined files", ["combined.txt"])
result = len(files)
"""

        executor = AgentExecutor()
        result = await executor.execute(code, ext_funcs, "test-agent")

        assert result.success is True
        assert result.return_value == 3  # file1, file2, combined

    @pytest.mark.asyncio
    async def test_agent_with_llm_calls(
        self, stable_fs, agent_fs, mock_llm_provider
    ):
        """Test agent using LLM calls."""
        await stable_fs.fs.write_file("code.py", b"def add(a, b):\\n    return a+b")

        ext_funcs = create_external_functions(
            "test-agent", agent_fs, stable_fs, mock_llm_provider
        )

        code = """
# Read code
code = read_file("code.py")

# Ask LLM to add docstring
improved = ask_llm("Add docstring", code)

# Write improved version
write_file("improved.py", improved)

submit_result("Added docstrings", ["improved.py"])
result = "done"
"""

        executor = AgentExecutor()
        result = await executor.execute(code, ext_funcs, "test-agent")

        assert result.success is True
        assert result.return_value == "done"

        # Verify LLM was called
        assert len(mock_llm_provider.calls) > 0

    @pytest.mark.asyncio
    async def test_resource_limits_enforced(self, stable_fs, agent_fs):
        """Test that resource limits are enforced during execution."""
        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        # Code that runs forever
        code = """
while True:
    pass
"""

        executor = AgentExecutor(max_execution_time=1)  # 1 second timeout
        result = await executor.execute(code, ext_funcs, "test-agent")

        assert result.success is False
        assert result.error_type == "timeout"

    @pytest.mark.asyncio
    async def test_submission_stored_in_kv(self, stable_fs, agent_fs):
        """Test that submission is properly stored in KV."""
        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        code = """
write_file("output.txt", "test content")
submit_result("Task completed", ["output.txt"])
result = "done"
"""

        executor = AgentExecutor()
        result = await executor.execute(code, ext_funcs, "test-agent")

        assert result.success is True

        # Verify submission in KV
        import json

        submission_str = await agent_fs.kv.get("submission")
        submission = json.loads(submission_str)

        assert submission["summary"] == "Task completed"
        assert "output.txt" in submission["changed_files"]
        assert "submitted_at" in submission
