"""Pydantic models for AgentFS SDK."""

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


class AgentFSOptions(BaseModel):
    """Options for opening an AgentFS filesystem.

    Either `id` or `path` must be provided.

    Examples:
        >>> options = AgentFSOptions(id="my-agent")
        >>> options = AgentFSOptions(path="./data/mydb.db")
    """

    id: Optional[str] = Field(
        None,
        description="Agent identifier (creates .agentfs/{id}.db)"
    )
    path: Optional[str] = Field(
        None,
        description="Custom database path"
    )

    @field_validator("id", "path")
    @classmethod
    def validate_id_or_path(cls, v, info):
        """Ensure at least one of id or path is provided."""
        return v

    def model_post_init(self, __context: Any) -> None:
        """Validate that at least one of id or path is provided."""
        if not self.id and not self.path:
            raise ValueError("Either 'id' or 'path' must be provided")


class FileStats(BaseModel):
    """File metadata from filesystem stat operation.

    Examples:
        >>> stats = FileStats(
        ...     size=1024,
        ...     mtime=datetime.now(),
        ...     is_file=True,
        ...     is_directory=False
        ... )
    """

    size: int = Field(description="File size in bytes")
    mtime: datetime = Field(description="Last modification time")
    is_file: bool = Field(description="True if entry is a file")
    is_directory: bool = Field(description="True if entry is a directory")

    def is_dir(self) -> bool:
        """Alias for is_directory."""
        return self.is_directory


class ToolCall(BaseModel):
    """Represents a tool/function call in the system.

    Examples:
        >>> call = ToolCall(
        ...     id=1,
        ...     name="search",
        ...     parameters={"query": "Python"},
        ...     result={"results": ["result1", "result2"]},
        ...     status="success",
        ...     started_at=datetime.now(),
        ...     completed_at=datetime.now()
        ... )
    """

    id: int = Field(description="Unique call identifier")
    name: str = Field(description="Tool/function name")
    parameters: dict[str, Any] = Field(
        default_factory=dict,
        description="Input parameters"
    )
    result: Optional[dict[str, Any]] = Field(
        None,
        description="Call result (for successful calls)"
    )
    error: Optional[str] = Field(
        None,
        description="Error message (for failed calls)"
    )
    status: str = Field(description="Call status: 'pending', 'success', or 'error'")
    started_at: datetime = Field(description="Call start timestamp")
    completed_at: Optional[datetime] = Field(
        None,
        description="Call completion timestamp"
    )
    duration_ms: Optional[float] = Field(
        None,
        description="Call duration in milliseconds"
    )


class ToolCallStats(BaseModel):
    """Statistics for a specific tool/function.

    Examples:
        >>> stats = ToolCallStats(
        ...     name="search",
        ...     total_calls=100,
        ...     successful=95,
        ...     failed=5,
        ...     avg_duration_ms=123.45
        ... )
    """

    name: str = Field(description="Tool/function name")
    total_calls: int = Field(description="Total number of calls")
    successful: int = Field(description="Number of successful calls")
    failed: int = Field(description="Number of failed calls")
    avg_duration_ms: float = Field(description="Average call duration in milliseconds")


class KVEntry(BaseModel):
    """Key-value store entry.

    Examples:
        >>> entry = KVEntry(key="user:123", value={"name": "Alice", "age": 30})
    """

    key: str = Field(description="Entry key")
    value: Any = Field(description="Entry value (JSON-serializable)")


class FileEntry(BaseModel):
    """Filesystem entry with path and optional metadata.

    Examples:
        >>> entry = FileEntry(
        ...     path="/data/config.json",
        ...     stats=FileStats(
        ...         size=1024,
        ...         mtime=datetime.now(),
        ...         is_file=True,
        ...         is_directory=False
        ...     )
        ... )
    """

    path: str = Field(description="File path")
    stats: Optional[FileStats] = Field(
        None,
        description="File statistics/metadata"
    )
    content: Optional[str | bytes] = Field(
        None,
        description="File content (if loaded)"
    )
