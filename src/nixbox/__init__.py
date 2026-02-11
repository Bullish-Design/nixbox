"""nixbox - AgentFS + devenv.sh dev environment management library.

This library provides type-safe Pydantic models for AgentFS SDK and utilities
for managing devenv.sh-based development environments with filesystem sandboxing.
"""

from .models import (
    AgentFSOptions,
    FileEntry,
    FileStats,
    KVEntry,
    ToolCall,
    ToolCallStats,
)
from .view import View, ViewQuery

__version__ = "0.1.0"

__all__ = [
    "AgentFSOptions",
    "FileEntry",
    "FileStats",
    "KVEntry",
    "ToolCall",
    "ToolCallStats",
    "View",
    "ViewQuery",
]
