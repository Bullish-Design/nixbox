# Step 11: Timeline Queries

**Phase**: 3 - Advanced
**Difficulty**: Easy
**Estimated Time**: 2-3 hours
**Prerequisites**: Phase 2

## Objective

Implement timeline query operations for auditing and debugging:
- Query operation history
- Filter by tool, status, time range
- Parse timeline entries
- Format output (JSON, pretty print)

## Why This Matters

Timeline queries enable:
- Auditing filesystem operations
- Debugging issues
- Understanding tool usage
- Analyzing performance

## Implementation Guide

### 11.1 Extend AgentFSCLI with Timeline Operations

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
class AgentFSCLI:
    # ... existing methods ...

    async def timeline(
        self,
        agent_id: str,
        *,
        query: Optional["TimelineQuery"] = None
    ) -> "TimelineResult":
        """Query operation timeline.

        Args:
            agent_id: Agent identifier
            query: Optional query parameters

        Returns:
            TimelineResult with entries

        Examples:
            >>> # Get recent operations
            >>> timeline = await cli.timeline("my-agent")
            >>>
            >>> # Filter by tool
            >>> timeline = await cli.timeline(
            ...     "my-agent",
            ...     query=TimelineQuery(
            ...         filter_tool="write_file",
            ...         limit=50
            ...     )
            ... )
            >>>
            >>> # Filter by status
            >>> errors = await cli.timeline(
            ...     "my-agent",
            ...     query=TimelineQuery(status="error")
            ... )
        """
        from agentfs_pydantic.models import TimelineQuery, TimelineResult, TimelineEntry
        from datetime import datetime
        import json

        args = ["timeline", agent_id]

        if query:
            if query.limit:
                args.extend(["--limit", str(query.limit)])

            if query.filter_tool:
                args.extend(["--filter-tool", query.filter_tool])

            if query.status:
                args.extend(["--status", query.status])

            if query.format:
                args.extend(["--format", query.format])

        result = await self.binary.execute(args)

        # Parse JSON output
        entries = []
        if result.success and result.stdout.strip():
            try:
                data = json.loads(result.stdout)
                for item in data:
                    entries.append(TimelineEntry(
                        timestamp=datetime.fromisoformat(item.get("timestamp", "")),
                        tool_name=item.get("tool_name", ""),
                        status=item.get("status", "pending"),
                        parameters=item.get("parameters", {}),
                        result=item.get("result"),
                        error=item.get("error"),
                        duration_ms=item.get("duration_ms")
                    ))
            except (json.JSONDecodeError, KeyError, ValueError):
                # Fallback to empty list if parsing fails
                pass

        return TimelineResult(entries=entries)
```

### 11.2 Create Timeline Module with Helpers

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/timeline.py`:

```python
"""Timeline query helpers and analysis."""

from datetime import datetime, timedelta
from typing import Optional, List
from collections import defaultdict

from agentfs_pydantic.cli import AgentFSCLI
from agentfs_pydantic.models import TimelineQuery, TimelineResult, TimelineEntry


class TimelineAnalyzer:
    """Analyze and filter timeline data.

    Examples:
        >>> analyzer = TimelineAnalyzer("my-agent")
        >>> await analyzer.load()
        >>>
        >>> # Get error summary
        >>> errors = analyzer.errors()
        >>> print(f"Found {len(errors)} errors")
        >>>
        >>> # Get tool usage stats
        >>> stats = analyzer.tool_stats()
        >>> for tool, count in stats.items():
        ...     print(f"{tool}: {count} calls")
    """

    def __init__(
        self,
        agent_id: str,
        *,
        cli: Optional[AgentFSCLI] = None
    ):
        """Initialize timeline analyzer.

        Args:
            agent_id: Agent to analyze
            cli: Optional CLI instance
        """
        self.agent_id = agent_id
        self.cli = cli or AgentFSCLI()
        self.timeline: Optional[TimelineResult] = None

    async def load(
        self,
        *,
        limit: int = 1000,
        filter_tool: Optional[str] = None
    ):
        """Load timeline data.

        Args:
            limit: Maximum entries to load
            filter_tool: Optional tool filter
        """
        query = TimelineQuery(limit=limit, filter_tool=filter_tool)
        self.timeline = await self.cli.timeline(self.agent_id, query=query)

    def errors(self) -> List[TimelineEntry]:
        """Get all error entries.

        Returns:
            List of error entries
        """
        if not self.timeline:
            return []
        return [e for e in self.timeline.entries if e.status == "error"]

    def by_tool(self, tool_name: str) -> List[TimelineEntry]:
        """Get entries for specific tool.

        Args:
            tool_name: Tool to filter by

        Returns:
            List of entries for that tool
        """
        if not self.timeline:
            return []
        return [e for e in self.timeline.entries if e.tool_name == tool_name]

    def tool_stats(self) -> dict[str, int]:
        """Get tool usage statistics.

        Returns:
            Dictionary mapping tool names to call counts
        """
        if not self.timeline:
            return {}

        stats = defaultdict(int)
        for entry in self.timeline.entries:
            stats[entry.tool_name] += 1
        return dict(stats)

    def success_rate(self) -> float:
        """Calculate overall success rate.

        Returns:
            Success rate as percentage (0-100)
        """
        if not self.timeline or not self.timeline.entries:
            return 0.0

        total = len(self.timeline.entries)
        successful = sum(1 for e in self.timeline.entries if e.status == "success")
        return (successful / total) * 100

    def recent(
        self,
        *,
        hours: int = 24
    ) -> List[TimelineEntry]:
        """Get recent entries.

        Args:
            hours: Number of hours back to look

        Returns:
            List of recent entries
        """
        if not self.timeline:
            return []

        cutoff = datetime.now() - timedelta(hours=hours)
        return [e for e in self.timeline.entries if e.timestamp >= cutoff]

    def avg_duration(self, tool_name: Optional[str] = None) -> float:
        """Calculate average operation duration.

        Args:
            tool_name: Optional tool to filter by

        Returns:
            Average duration in milliseconds
        """
        if not self.timeline:
            return 0.0

        entries = self.timeline.entries
        if tool_name:
            entries = [e for e in entries if e.tool_name == tool_name]

        durations = [e.duration_ms for e in entries if e.duration_ms is not None]
        if not durations:
            return 0.0

        return sum(durations) / len(durations)

    def summary(self) -> dict:
        """Get summary statistics.

        Returns:
            Dictionary with summary stats
        """
        if not self.timeline:
            return {}

        return {
            "total_entries": self.timeline.total_entries,
            "successful": self.timeline.success_count,
            "errors": self.timeline.error_count,
            "success_rate": self.success_rate(),
            "tool_stats": self.tool_stats(),
            "avg_duration_ms": self.avg_duration(),
        }


async def get_recent_errors(
    agent_id: str,
    *,
    hours: int = 24,
    cli: Optional[AgentFSCLI] = None
) -> List[TimelineEntry]:
    """Get recent error entries.

    Convenience function for quick error checks.

    Args:
        agent_id: Agent to check
        hours: How many hours back to check
        cli: Optional CLI instance

    Returns:
        List of recent error entries

    Examples:
        >>> errors = await get_recent_errors("my-agent", hours=24)
        >>> for error in errors:
        ...     print(f"{error.timestamp}: {error.error}")
    """
    analyzer = TimelineAnalyzer(agent_id, cli=cli)
    await analyzer.load()
    recent = analyzer.recent(hours=hours)
    return [e for e in recent if e.status == "error"]
```

### 11.3 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.timeline import TimelineAnalyzer, get_recent_errors

__all__ = [
    # ... existing ...
    "TimelineAnalyzer",
    "get_recent_errors",
]
```

### 11.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_timeline.py`:

```python
"""Tests for timeline operations."""

import pytest
from pathlib import Path

from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    FSOperations,
    TimelineQuery,
    TimelineAnalyzer,
    get_recent_errors,
)


@pytest.fixture
async def agent_with_history():
    """Create agent with some history."""
    cli = AgentFSCLI()
    agent_id = "timeline-test"
    await cli.init(agent_id, options=InitOptions(force=True))

    # Create some operations
    fs = FSOperations(agent_id)
    await fs.write("/file1.txt", "data1")
    await fs.write("/file2.txt", "data2")
    await fs.cat("/file1.txt")

    yield agent_id

    # Cleanup
    import os
    db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
    if db_path.exists():
        os.remove(db_path)


class TestTimeline:
    """Tests for timeline operations."""

    @pytest.mark.asyncio
    async def test_timeline_query(self, agent_with_history):
        """Test basic timeline query."""
        cli = AgentFSCLI()
        timeline = await cli.timeline(agent_with_history)

        assert timeline is not None
        assert isinstance(timeline.entries, list)

    @pytest.mark.asyncio
    async def test_timeline_with_limit(self, agent_with_history):
        """Test timeline query with limit."""
        cli = AgentFSCLI()
        query = TimelineQuery(limit=2)
        timeline = await cli.timeline(agent_with_history, query=query)

        assert len(timeline.entries) <= 2

    @pytest.mark.asyncio
    async def test_timeline_filter_by_tool(self, agent_with_history):
        """Test filtering by tool name."""
        cli = AgentFSCLI()
        query = TimelineQuery(filter_tool="write_file")
        timeline = await cli.timeline(agent_with_history, query=query)

        # All entries should be write_file
        for entry in timeline.entries:
            assert entry.tool_name == "write_file"


class TestTimelineAnalyzer:
    """Tests for timeline analyzer."""

    @pytest.mark.asyncio
    async def test_analyzer_load(self, agent_with_history):
        """Test loading timeline data."""
        analyzer = TimelineAnalyzer(agent_with_history)
        await analyzer.load()

        assert analyzer.timeline is not None
        assert len(analyzer.timeline.entries) > 0

    @pytest.mark.asyncio
    async def test_tool_stats(self, agent_with_history):
        """Test tool statistics."""
        analyzer = TimelineAnalyzer(agent_with_history)
        await analyzer.load()

        stats = analyzer.tool_stats()
        assert isinstance(stats, dict)
        assert len(stats) > 0

    @pytest.mark.asyncio
    async def test_success_rate(self, agent_with_history):
        """Test success rate calculation."""
        analyzer = TimelineAnalyzer(agent_with_history)
        await analyzer.load()

        rate = analyzer.success_rate()
        assert 0.0 <= rate <= 100.0

    @pytest.mark.asyncio
    async def test_summary(self, agent_with_history):
        """Test summary statistics."""
        analyzer = TimelineAnalyzer(agent_with_history)
        await analyzer.load()

        summary = analyzer.summary()
        assert "total_entries" in summary
        assert "successful" in summary
        assert "tool_stats" in summary
```

## Testing

### Manual Testing

```python
import asyncio
from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    FSOperations,
    TimelineQuery,
    TimelineAnalyzer,
)

async def main():
    cli = AgentFSCLI()

    # Setup
    await cli.init("timeline-demo", options=InitOptions(force=True))
    fs = FSOperations("timeline-demo")

    # Create some operations
    await fs.write("/test1.txt", "data1")
    await fs.write("/test2.txt", "data2")
    await fs.cat("/test1.txt")
    await fs.mkdir("/newdir")

    # Query timeline
    print("1. Full timeline:")
    timeline = await cli.timeline("timeline-demo")
    print(f"Total entries: {len(timeline.entries)}")

    # Filtered query
    print("\n2. Filtered timeline:")
    query = TimelineQuery(filter_tool="write_file", limit=10)
    timeline = await cli.timeline("timeline-demo", query=query)
    for entry in timeline.entries:
        print(f"  {entry.timestamp}: {entry.tool_name} - {entry.status}")

    # Analyze
    print("\n3. Timeline analysis:")
    analyzer = TimelineAnalyzer("timeline-demo")
    await analyzer.load()

    summary = analyzer.summary()
    print(f"Total operations: {summary['total_entries']}")
    print(f"Success rate: {summary['success_rate']:.1f}%")
    print(f"Tool usage: {summary['tool_stats']}")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_timeline.py -v
```

## Success Criteria

- [ ] timeline operation implemented
- [ ] TimelineQuery filters work (tool, status, limit)
- [ ] Timeline entries parsed correctly
- [ ] TimelineAnalyzer provides statistics
- [ ] Helper functions (errors, tool_stats, etc.) work
- [ ] get_recent_errors convenience function works
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: JSON parsing errors
- **Solution**: Handle malformed JSON gracefully

**Issue**: Timestamp parsing fails
- **Solution**: Use flexible datetime parsing

**Issue**: Empty timeline
- **Solution**: Check that operations were actually performed

## Next Steps

Once this step is complete:
1. Proceed to [Step 12: Diff Operations](./DEV_GUIDE-STEP_12.md)
2. Timeline queries help with debugging all operations

## Design Notes

- Timeline data is always JSON format
- Analyzer provides high-level statistics
- Filters can be combined
- Timestamps are ISO format
- Helper functions for common queries
