"""View interface for querying AgentFS filesystem."""

import fnmatch
import re
from typing import TYPE_CHECKING, Any, Callable, Optional

from pydantic import BaseModel, Field

from .models import FileEntry, FileStats

if TYPE_CHECKING:
    from agentfs_sdk import AgentFS
else:
    try:
        from agentfs_sdk import AgentFS
    except ImportError:
        # AgentFS is optional - only needed for actual filesystem operations
        AgentFS = Any  # type: ignore


class ViewQuery(BaseModel):
    """Query specification for filesystem views.

    Examples:
        >>> query = ViewQuery(
        ...     path_pattern="*.py",
        ...     recursive=True,
        ...     include_content=True
        ... )
    """

    path_pattern: str = Field(
        default="*",
        description="Glob pattern for matching file paths (e.g., '*.py', '/data/**/*.json')"
    )
    recursive: bool = Field(
        default=True,
        description="Whether to search recursively in subdirectories"
    )
    include_content: bool = Field(
        default=False,
        description="Whether to load file contents"
    )
    include_stats: bool = Field(
        default=True,
        description="Whether to include file statistics"
    )
    regex_pattern: Optional[str] = Field(
        None,
        description="Optional regex pattern for more complex matching"
    )
    max_size: Optional[int] = Field(
        None,
        description="Maximum file size in bytes (files larger than this are excluded)"
    )
    min_size: Optional[int] = Field(
        None,
        description="Minimum file size in bytes (files smaller than this are excluded)"
    )


class View(BaseModel):
    """View of the AgentFS filesystem with query capabilities.

    A View represents a filtered/queried view of the filesystem based on
    a query specification. It provides methods to load matching files.

    Examples:
        >>> async with await AgentFS.open(AgentFSOptions(id="my-agent")) as agent:
        ...     view = View(agent=agent, query=ViewQuery(path_pattern="*.py"))
        ...     files = await view.load()
        ...     for file in files:
        ...         print(f"{file.path}: {file.stats.size} bytes")
    """

    model_config = {"arbitrary_types_allowed": True}

    agent: AgentFS = Field(description="AgentFS instance")
    query: ViewQuery = Field(
        default_factory=ViewQuery,
        description="Query specification"
    )

    async def load(self) -> list[FileEntry]:
        """Load files matching the query specification.

        Returns:
            List of FileEntry objects matching the query

        Examples:
            >>> files = await view.load()
            >>> for file in files:
            ...     print(file.path)
        """
        entries: list[FileEntry] = []

        # Start from root
        await self._scan_directory("/", entries)

        # Apply size filters
        if self.query.max_size is not None or self.query.min_size is not None:
            entries = [
                e for e in entries
                if self._matches_size_filter(e)
            ]

        # Apply regex pattern if provided
        if self.query.regex_pattern:
            pattern = re.compile(self.query.regex_pattern)
            entries = [
                e for e in entries
                if pattern.search(e.path)
            ]

        return entries

    async def _scan_directory(
        self,
        path: str,
        entries: list[FileEntry]
    ) -> None:
        """Recursively scan a directory for matching files.

        Args:
            path: Directory path to scan
            entries: List to append matching entries to
        """
        try:
            # List directory contents
            items = await self.agent.fs.readdir(path)

            for item in items:
                # Construct full path
                item_path = f"{path.rstrip('/')}/{item}"

                try:
                    # Get file stats
                    stats = await self.agent.fs.stat(item_path)

                    # Convert to our FileStats model
                    file_stats = FileStats(
                        size=stats.size,
                        mtime=stats.mtime,
                        is_file=stats.is_file(),
                        is_directory=stats.is_dir()
                    )

                    if file_stats.is_directory:
                        # Recursively scan subdirectory if enabled
                        if self.query.recursive:
                            await self._scan_directory(item_path, entries)
                    elif file_stats.is_file:
                        # Check if file matches pattern
                        if self._matches_pattern(item_path):
                            # Load content if requested
                            content = None
                            if self.query.include_content:
                                try:
                                    content = await self.agent.fs.read_file(item_path)
                                except Exception:
                                    # If content loading fails, continue without it
                                    content = None

                            # Create entry
                            entry = FileEntry(
                                path=item_path,
                                stats=file_stats if self.query.include_stats else None,
                                content=content
                            )
                            entries.append(entry)

                except Exception:
                    # Skip files that can't be accessed
                    continue

        except Exception:
            # Skip directories that can't be accessed
            pass

    def _matches_pattern(self, path: str) -> bool:
        """Check if a path matches the query pattern.

        Args:
            path: File path to check

        Returns:
            True if path matches the pattern
        """
        pattern = self.query.path_pattern

        # Handle different pattern types
        if "**" in pattern:
            # Handle recursive glob patterns
            # Convert ** pattern to regex
            regex_pattern = pattern.replace("**", ".*").replace("*", "[^/]*")
            return bool(re.match(regex_pattern, path))
        else:
            # Use simple fnmatch for non-recursive patterns
            return fnmatch.fnmatch(path, pattern)

    def _matches_size_filter(self, entry: FileEntry) -> bool:
        """Check if an entry matches size filters.

        Args:
            entry: File entry to check

        Returns:
            True if entry matches size constraints
        """
        if not entry.stats:
            return True

        if self.query.min_size is not None:
            if entry.stats.size < self.query.min_size:
                return False

        if self.query.max_size is not None:
            if entry.stats.size > self.query.max_size:
                return False

        return True

    async def filter(
        self,
        predicate: Callable[[FileEntry], bool]
    ) -> list[FileEntry]:
        """Load and filter files using a custom predicate function.

        Args:
            predicate: Function that takes a FileEntry and returns bool

        Returns:
            List of FileEntry objects that match the predicate

        Examples:
            >>> # Get only files larger than 1KB
            >>> large_files = await view.filter(lambda f: f.stats.size > 1024)
        """
        entries = await self.load()
        return [e for e in entries if predicate(e)]

    async def count(self) -> int:
        """Count files matching the query without loading content.

        Returns:
            Number of matching files

        Examples:
            >>> count = await view.count()
            >>> print(f"Found {count} matching files")
        """
        # Temporarily disable content loading for counting
        original_include_content = self.query.include_content
        self.query.include_content = False

        try:
            entries = await self.load()
            return len(entries)
        finally:
            # Restore original setting
            self.query.include_content = original_include_content

    def with_pattern(self, pattern: str) -> "View":
        """Create a new view with a different path pattern.

        Args:
            pattern: New glob pattern

        Returns:
            New View instance with updated pattern

        Examples:
            >>> python_files = view.with_pattern("*.py")
            >>> json_files = view.with_pattern("**/*.json")
        """
        new_query = self.query.model_copy(update={"path_pattern": pattern})
        return View(agent=self.agent, query=new_query)

    def with_content(self, include: bool = True) -> "View":
        """Create a new view with content loading enabled or disabled.

        Args:
            include: Whether to include file contents

        Returns:
            New View instance with updated content setting

        Examples:
            >>> view_with_content = view.with_content(True)
        """
        new_query = self.query.model_copy(update={"include_content": include})
        return View(agent=self.agent, query=new_query)
