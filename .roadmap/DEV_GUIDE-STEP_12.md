# Step 12: Diff Operations

**Phase**: 3 - Advanced
**Difficulty**: Easy
**Estimated Time**: 2 hours
**Prerequisites**: Phase 2

## Objective

Implement diff operations to show changes in overlay filesystems:
- Show added files
- Show modified files
- Show deleted files
- Parse diff output into structured format

## Why This Matters

Diff operations enable:
- Understanding overlay changes
- Reviewing modifications before commit
- Debugging copy-on-write behavior
- Generating change reports

## Implementation Guide

### 12.1 Extend AgentFSCLI with Diff Operations

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
class AgentFSCLI:
    # ... existing methods ...

    async def diff(
        self,
        agent_id: str,
        *,
        format: str = "json"
    ) -> "DiffResult":
        """Show changes in overlay filesystem.

        Args:
            agent_id: Agent identifier (must be overlay)
            format: Output format (json or text)

        Returns:
            DiffResult with changes

        Examples:
            >>> # Show all changes
            >>> diff = await cli.diff("overlay-agent")
            >>> print(f"Added: {diff.added_count}")
            >>> print(f"Modified: {diff.modified_count}")
            >>> print(f"Deleted: {diff.deleted_count}")
            >>>
            >>> # Iterate changes
            >>> for change in diff.changes:
            ...     print(f"{change.type}: {change.path}")
        """
        from agentfs_pydantic.models import DiffResult, DiffChange
        import json

        args = ["diff", agent_id]

        if format:
            args.extend(["--format", format])

        result = await self.binary.execute(args)

        # Parse output
        changes = []
        if result.success and result.stdout.strip():
            try:
                if format == "json":
                    data = json.loads(result.stdout)
                    for item in data:
                        changes.append(DiffChange(
                            type=item.get("type", "modified"),
                            path=item.get("path", ""),
                            before_size=item.get("before_size"),
                            after_size=item.get("after_size")
                        ))
                else:
                    # Parse text format
                    # Example: "A /newfile.txt (size: 100)"
                    #          "M /existing.txt (50 -> 75)"
                    #          "D /deleted.txt (size: 200)"
                    for line in result.stdout.strip().split('\n'):
                        if not line:
                            continue

                        parts = line.split(None, 1)
                        if len(parts) < 2:
                            continue

                        type_char = parts[0]
                        rest = parts[1]

                        # Map type character to type name
                        type_map = {"A": "added", "M": "modified", "D": "deleted"}
                        change_type = type_map.get(type_char, "modified")

                        # Extract path
                        path = rest.split()[0]

                        changes.append(DiffChange(
                            type=change_type,
                            path=path,
                            before_size=None,
                            after_size=None
                        ))
            except (json.JSONDecodeError, KeyError, ValueError):
                # Return empty changes if parsing fails
                pass

        return DiffResult(changes=changes)
```

### 12.2 Create Diff Module with Helpers

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/diff.py`:

```python
"""Diff operations and analysis."""

from typing import Optional, List
from pathlib import Path

from agentfs_pydantic.cli import AgentFSCLI
from agentfs_pydantic.models import DiffResult, DiffChange


class DiffAnalyzer:
    """Analyze diff results.

    Examples:
        >>> analyzer = DiffAnalyzer("overlay-agent")
        >>> await analyzer.load()
        >>>
        >>> # Get files by extension
        >>> python_files = analyzer.by_extension(".py")
        >>>
        >>> # Get large changes
        >>> large = analyzer.large_changes(min_size=1000)
    """

    def __init__(
        self,
        agent_id: str,
        *,
        cli: Optional[AgentFSCLI] = None
    ):
        """Initialize diff analyzer.

        Args:
            agent_id: Overlay agent to analyze
            cli: Optional CLI instance
        """
        self.agent_id = agent_id
        self.cli = cli or AgentFSCLI()
        self.diff: Optional[DiffResult] = None

    async def load(self):
        """Load diff data."""
        self.diff = await self.cli.diff(self.agent_id)

    def by_type(self, change_type: str) -> List[DiffChange]:
        """Get changes by type.

        Args:
            change_type: "added", "modified", or "deleted"

        Returns:
            List of matching changes
        """
        if not self.diff:
            return []
        return [c for c in self.diff.changes if c.type == change_type]

    def by_extension(self, ext: str) -> List[DiffChange]:
        """Get changes for files with given extension.

        Args:
            ext: File extension (e.g., ".py", ".json")

        Returns:
            List of matching changes
        """
        if not self.diff:
            return []
        return [c for c in self.diff.changes if c.path.endswith(ext)]

    def by_directory(self, directory: str) -> List[DiffChange]:
        """Get changes in a directory.

        Args:
            directory: Directory path

        Returns:
            List of matching changes
        """
        if not self.diff:
            return []
        dir_path = directory.rstrip('/') + '/'
        return [c for c in self.diff.changes if c.path.startswith(dir_path)]

    def large_changes(self, min_size: int = 1000) -> List[DiffChange]:
        """Get changes involving large files.

        Args:
            min_size: Minimum size in bytes

        Returns:
            List of changes with size >= min_size
        """
        if not self.diff:
            return []

        result = []
        for change in self.diff.changes:
            if change.before_size and change.before_size >= min_size:
                result.append(change)
            elif change.after_size and change.after_size >= min_size:
                result.append(change)

        return result

    def summary_by_type(self) -> dict[str, int]:
        """Get count of changes by type.

        Returns:
            Dictionary mapping type to count
        """
        if not self.diff:
            return {}

        return {
            "added": self.diff.added_count,
            "modified": self.diff.modified_count,
            "deleted": self.diff.deleted_count,
        }

    def total_size_change(self) -> int:
        """Calculate total size change in bytes.

        Returns:
            Net size change (positive = growth, negative = shrink)
        """
        if not self.diff:
            return 0

        total = 0
        for change in self.diff.changes:
            before = change.before_size or 0
            after = change.after_size or 0
            total += (after - before)

        return total


async def quick_diff(
    agent_id: str,
    *,
    cli: Optional[AgentFSCLI] = None
) -> dict:
    """Quick diff summary.

    Convenience function for getting diff stats.

    Args:
        agent_id: Overlay agent
        cli: Optional CLI instance

    Returns:
        Dictionary with summary stats

    Examples:
        >>> summary = await quick_diff("overlay-agent")
        >>> print(f"Added: {summary['added']}")
        >>> print(f"Modified: {summary['modified']}")
        >>> print(f"Deleted: {summary['deleted']}")
    """
    analyzer = DiffAnalyzer(agent_id, cli=cli)
    await analyzer.load()

    return {
        "added": analyzer.diff.added_count if analyzer.diff else 0,
        "modified": analyzer.diff.modified_count if analyzer.diff else 0,
        "deleted": analyzer.diff.deleted_count if analyzer.diff else 0,
        "total": analyzer.diff.total_changes if analyzer.diff else 0,
        "size_change": analyzer.total_size_change(),
    }


async def has_changes(
    agent_id: str,
    *,
    cli: Optional[AgentFSCLI] = None
) -> bool:
    """Check if overlay has any changes.

    Args:
        agent_id: Overlay agent
        cli: Optional CLI instance

    Returns:
        True if there are changes

    Examples:
        >>> if await has_changes("overlay-agent"):
        ...     print("Overlay has been modified")
    """
    cli = cli or AgentFSCLI()
    diff = await cli.diff(agent_id)
    return diff.total_changes > 0
```

### 12.3 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.diff import DiffAnalyzer, quick_diff, has_changes

__all__ = [
    # ... existing ...
    "DiffAnalyzer",
    "quick_diff",
    "has_changes",
]
```

### 12.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_diff.py`:

```python
"""Tests for diff operations."""

import pytest
import tempfile
from pathlib import Path

from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    FSOperations,
    DiffAnalyzer,
    quick_diff,
    has_changes,
)


@pytest.fixture
async def overlay_agent():
    """Create overlay agent with changes."""
    cli = AgentFSCLI()
    agent_id = "diff-test"

    # Create base directory
    with tempfile.TemporaryDirectory() as tmpdir:
        base = Path(tmpdir)
        (base / "original.txt").write_text("original content")
        (base / "modify.txt").write_text("will be modified")
        (base / "delete.txt").write_text("will be deleted")

        # Initialize overlay
        await cli.init(
            agent_id,
            options=InitOptions(force=True, base=base)
        )

        # Make changes
        fs = FSOperations(agent_id)
        await fs.write("/new.txt", "new file")  # Added
        await fs.write("/modify.txt", "modified content")  # Modified
        await fs.rm("/delete.txt")  # Deleted

        yield agent_id

    # Cleanup
    import os
    db_path = Path.home() / ".agentfs" / f"{agent_id}.db"
    if db_path.exists():
        os.remove(db_path)


class TestDiff:
    """Tests for diff operations."""

    @pytest.mark.asyncio
    async def test_diff_basic(self, overlay_agent):
        """Test basic diff operation."""
        cli = AgentFSCLI()
        diff = await cli.diff(overlay_agent)

        assert diff is not None
        assert diff.total_changes > 0

    @pytest.mark.asyncio
    async def test_diff_counts(self, overlay_agent):
        """Test diff change counts."""
        cli = AgentFSCLI()
        diff = await cli.diff(overlay_agent)

        # Should have at least one of each type
        assert diff.added_count > 0 or diff.modified_count > 0 or diff.deleted_count > 0

    @pytest.mark.asyncio
    async def test_diff_analyzer(self, overlay_agent):
        """Test diff analyzer."""
        analyzer = DiffAnalyzer(overlay_agent)
        await analyzer.load()

        assert analyzer.diff is not None

        # Test filtering
        added = analyzer.by_type("added")
        assert isinstance(added, list)

    @pytest.mark.asyncio
    async def test_quick_diff(self, overlay_agent):
        """Test quick diff helper."""
        summary = await quick_diff(overlay_agent)

        assert "added" in summary
        assert "modified" in summary
        assert "deleted" in summary
        assert "total" in summary

    @pytest.mark.asyncio
    async def test_has_changes(self, overlay_agent):
        """Test has_changes helper."""
        result = await has_changes(overlay_agent)
        assert result is True
```

## Testing

### Manual Testing

```python
import asyncio
import tempfile
from pathlib import Path
from agentfs_pydantic import (
    AgentFSCLI,
    InitOptions,
    FSOperations,
    DiffAnalyzer,
    quick_diff,
)

async def main():
    cli = AgentFSCLI()

    # Create base directory
    with tempfile.TemporaryDirectory() as tmpdir:
        base = Path(tmpdir)
        (base / "file1.txt").write_text("original")
        (base / "file2.txt").write_text("original")

        # Create overlay
        await cli.init("diff-demo", options=InitOptions(force=True, base=base))

        # Make changes
        fs = FSOperations("diff-demo")
        await fs.write("/new.txt", "new file")
        await fs.write("/file1.txt", "modified")
        await fs.rm("/file2.txt")

        # Show diff
        print("1. Basic diff:")
        diff = await cli.diff("diff-demo")
        print(f"Total changes: {diff.total_changes}")
        print(f"Added: {diff.added_count}")
        print(f"Modified: {diff.modified_count}")
        print(f"Deleted: {diff.deleted_count}")

        print("\n2. Change details:")
        for change in diff.changes:
            print(f"  {change.type}: {change.path}")

        print("\n3. Quick summary:")
        summary = await quick_diff("diff-demo")
        print(summary)

        print("\n4. Analyzer:")
        analyzer = DiffAnalyzer("diff-demo")
        await analyzer.load()
        print(f"Summary by type: {analyzer.summary_by_type()}")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_diff.py -v
```

## Success Criteria

- [ ] diff operation implemented
- [ ] DiffResult properly parses changes
- [ ] Added/modified/deleted counts work
- [ ] DiffAnalyzer provides filtering
- [ ] quick_diff convenience function works
- [ ] has_changes helper works
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Diff shows no changes
- **Solution**: Ensure agent is an overlay (has --base)

**Issue**: Parsing errors
- **Solution**: Handle both JSON and text formats

**Issue**: Size information missing
- **Solution**: Check CLI output format for size data

## Next Steps

Once this step is complete:
1. Proceed to [Step 13: Migration Support](./DEV_GUIDE-STEP_13.md)
2. Diff operations useful for reviewing changes before sync

## Design Notes

- Diff only works for overlay agents
- Changes are categorized as added/modified/deleted
- Size information helps assess impact
- Analyzer provides convenient filtering
- Helper functions for common patterns
