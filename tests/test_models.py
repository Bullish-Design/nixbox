"""Tests for nixbox models."""

from datetime import datetime

import pytest
from nixbox import (
    AgentFSOptions,
    FileEntry,
    FileStats,
    KVEntry,
    ToolCall,
    ToolCallStats,
    ViewQuery,
)


def test_agentfs_options_with_id():
    """Test AgentFSOptions with id parameter."""
    options = AgentFSOptions(id="test-agent")
    assert options.id == "test-agent"
    assert options.path is None


def test_agentfs_options_with_path():
    """Test AgentFSOptions with path parameter."""
    options = AgentFSOptions(path="/tmp/test.db")
    assert options.path == "/tmp/test.db"
    assert options.id is None


def test_agentfs_options_requires_id_or_path():
    """Test that AgentFSOptions requires either id or path."""
    with pytest.raises(ValueError, match="Either 'id' or 'path' must be provided"):
        AgentFSOptions()


def test_file_stats():
    """Test FileStats model."""
    now = datetime.now()
    stats = FileStats(
        size=1024,
        mtime=now,
        is_file=True,
        is_directory=False
    )

    assert stats.size == 1024
    assert stats.mtime == now
    assert stats.is_file is True
    assert stats.is_directory is False
    assert stats.is_dir() is False


def test_file_entry():
    """Test FileEntry model."""
    now = datetime.now()
    stats = FileStats(
        size=1024,
        mtime=now,
        is_file=True,
        is_directory=False
    )

    entry = FileEntry(
        path="/test/file.txt",
        stats=stats,
        content="test content"
    )

    assert entry.path == "/test/file.txt"
    assert entry.stats == stats
    assert entry.content == "test content"


def test_file_entry_minimal():
    """Test FileEntry with minimal data."""
    entry = FileEntry(path="/test/file.txt")

    assert entry.path == "/test/file.txt"
    assert entry.stats is None
    assert entry.content is None


def test_tool_call():
    """Test ToolCall model."""
    now = datetime.now()
    call = ToolCall(
        id=1,
        name="search",
        parameters={"query": "test"},
        result={"results": ["result1"]},
        status="success",
        started_at=now,
        completed_at=now,
        duration_ms=123.45
    )

    assert call.id == 1
    assert call.name == "search"
    assert call.parameters == {"query": "test"}
    assert call.result == {"results": ["result1"]}
    assert call.status == "success"
    assert call.error is None


def test_tool_call_stats():
    """Test ToolCallStats model."""
    stats = ToolCallStats(
        name="search",
        total_calls=100,
        successful=95,
        failed=5,
        avg_duration_ms=123.45
    )

    assert stats.name == "search"
    assert stats.total_calls == 100
    assert stats.successful == 95
    assert stats.failed == 5
    assert stats.avg_duration_ms == 123.45


def test_kv_entry():
    """Test KVEntry model."""
    entry = KVEntry(
        key="user:123",
        value={"name": "Alice", "age": 30}
    )

    assert entry.key == "user:123"
    assert entry.value == {"name": "Alice", "age": 30}


def test_view_query_defaults():
    """Test ViewQuery with default values."""
    query = ViewQuery()

    assert query.path_pattern == "*"
    assert query.recursive is True
    assert query.include_content is False
    assert query.include_stats is True
    assert query.regex_pattern is None
    assert query.max_size is None
    assert query.min_size is None


def test_view_query_custom():
    """Test ViewQuery with custom values."""
    query = ViewQuery(
        path_pattern="*.py",
        recursive=False,
        include_content=True,
        include_stats=False,
        regex_pattern=r"^/src/",
        max_size=10000,
        min_size=100
    )

    assert query.path_pattern == "*.py"
    assert query.recursive is False
    assert query.include_content is True
    assert query.include_stats is False
    assert query.regex_pattern == r"^/src/"
    assert query.max_size == 10000
    assert query.min_size == 100


def test_model_serialization():
    """Test that models can be serialized to JSON."""
    options = AgentFSOptions(id="test-agent")
    json_data = options.model_dump_json()

    assert "test-agent" in json_data

    # Test deserialization
    restored = AgentFSOptions.model_validate_json(json_data)
    assert restored.id == "test-agent"
