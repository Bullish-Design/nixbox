"""Unit tests for external functions.

Tests implement all contracts from ROADMAP-STEP_2.md.
"""

import json

import pytest
from agentfs_sdk import AgentFS
from agentfs_pydantic import AgentFSOptions

from cairn.external_functions import create_external_functions


class TestExternalFunctions:
    """Test external functions interface."""

    @pytest.mark.asyncio
    async def test_read_file_fallthrough(self, stable_fs, agent_fs):
        """Contract 1: read_file falls through to stable."""
        await stable_fs.fs.write_file("test.txt", b"stable content")

        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)
        content = await ext_funcs["read_file"]("test.txt")

        assert content == "stable content"

    @pytest.mark.asyncio
    async def test_write_file_isolation(self, stable_fs, agent_fs):
        """Contract 2: write_file only to overlay."""
        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)
        result = await ext_funcs["write_file"]("new.txt", "agent content")

        assert result is True
        agent_content = await agent_fs.fs.read_file("new.txt")
        assert agent_content == b"agent content"

        # Stable should not have the file
        with pytest.raises(FileNotFoundError):
            await stable_fs.fs.read_file("new.txt")

    @pytest.mark.asyncio
    async def test_search_files(self, stable_fs, agent_fs):
        """Contract 3: search_files uses glob patterns."""
        # Create files
        await agent_fs.fs.write_file("main.py", b"")
        await agent_fs.fs.write_file("test.py", b"")
        await agent_fs.fs.write_file("README.md", b"")

        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)
        py_files = await ext_funcs["search_files"]("*.py")

        assert len(py_files) == 2
        assert "main.py" in py_files
        assert "test.py" in py_files
        assert "README.md" not in py_files

    @pytest.mark.asyncio
    async def test_search_content(self, stable_fs, agent_fs):
        """Contract 4: search_content returns structured results."""
        await agent_fs.fs.write_file("main.py", b"def hello():\n    print('hello')")

        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)
        results = await ext_funcs["search_content"]("hello", ".")

        assert len(results) > 0
        assert results[0]["file"] == "main.py"
        assert "line" in results[0]
        assert "text" in results[0]

    @pytest.mark.asyncio
    async def test_ask_llm(self, stable_fs, agent_fs, mock_llm_provider):
        """Contract 5: ask_llm integrates with LLM provider."""
        ext_funcs = create_external_functions(
            "test-agent", agent_fs, stable_fs, mock_llm_provider
        )
        response = await ext_funcs["ask_llm"]("What is 2+2?", "")

        assert isinstance(response, str)
        assert len(response) > 0

    @pytest.mark.asyncio
    async def test_submit_result(self, stable_fs, agent_fs):
        """Contract 6: submit_result stores in KV."""
        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        result = await ext_funcs["submit_result"](
            "Added docstrings", ["main.py", "utils.py"]
        )

        assert result is True

        # Verify stored in KV
        submission_str = await agent_fs.kv.get("submission")
        submission = json.loads(submission_str)
        assert submission["summary"] == "Added docstrings"
        assert submission["changed_files"] == ["main.py", "utils.py"]

    @pytest.mark.asyncio
    async def test_file_exists(self, stable_fs, agent_fs):
        """Test file_exists function."""
        await agent_fs.fs.write_file("exists.txt", b"content")

        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        assert await ext_funcs["file_exists"]("exists.txt") is True
        assert await ext_funcs["file_exists"]("missing.txt") is False

    @pytest.mark.asyncio
    async def test_list_dir(self, stable_fs, agent_fs):
        """Test list_dir function."""
        await agent_fs.fs.write_file("file1.txt", b"")
        await agent_fs.fs.write_file("file2.txt", b"")

        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)
        files = await ext_funcs["list_dir"]("/")

        assert len(files) >= 2
        assert "file1.txt" in files
        assert "file2.txt" in files

    @pytest.mark.asyncio
    async def test_log(self, stable_fs, agent_fs, capsys):
        """Test log function."""
        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)
        result = await ext_funcs["log"]("Test message")

        assert result is True
        captured = capsys.readouterr()
        assert "test-agent" in captured.out
        assert "Test message" in captured.out

    @pytest.mark.asyncio
    async def test_invalid_path_rejected(self, stable_fs, agent_fs):
        """Test that invalid paths are rejected."""
        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        with pytest.raises(ValueError, match="Invalid path"):
            await ext_funcs["read_file"]("../etc/passwd")

        with pytest.raises(ValueError, match="Invalid path"):
            await ext_funcs["write_file"]("/etc/passwd", "hacked")

    @pytest.mark.asyncio
    async def test_file_size_limit(self, stable_fs, agent_fs):
        """Test that file size limits are enforced."""
        # Create large content (> 10MB)
        large_content = "x" * (11 * 1024 * 1024)

        ext_funcs = create_external_functions("test-agent", agent_fs, stable_fs)

        with pytest.raises(ValueError, match="too large"):
            await ext_funcs["write_file"]("large.txt", large_content)
