# Step 16: Testing Utilities

**Phase**: 4 - Quality
**Difficulty**: Easy
**Estimated Time**: 2-3 hours
**Prerequisites**: Phase 3

## Objective

Create testing utilities to make testing AgentFS code easier:
- Test fixtures and helpers
- Mock agents for unit testing
- Assertion helpers
- Test data generators
- Integration test support

## Why This Matters

Testing utilities enable:
- Faster test development
- More reliable tests
- Better test coverage
- Easier debugging
- TDD workflows

## Implementation Guide

### 16.1 Create Testing Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/testing.py`:

```python
"""Testing utilities for AgentFS applications."""

import asyncio
import tempfile
import uuid
from pathlib import Path
from typing import Optional, AsyncIterator
from contextlib import asynccontextmanager

from agentfs_pydantic.cli import AgentFSCLI
from agentfs_pydantic.models import InitOptions
from agentfs_pydantic.filesystem import FSOperations
from agentfs_pydantic.mount import mount_context


class MockAgent:
    """Mock AgentFS instance for testing.

    Automatically creates and cleans up a temporary agent.

    Examples:
        >>> async with MockAgent() as agent:
        ...     await agent.fs.write("/test.txt", "data")
        ...     content = await agent.fs.cat("/test.txt")
        ...     assert content == "data"
    """

    def __init__(
        self,
        *,
        agent_id: Optional[str] = None,
        base: Optional[Path] = None,
        cli: Optional[AgentFSCLI] = None
    ):
        """Initialize mock agent.

        Args:
            agent_id: Optional agent ID (generated if not provided)
            base: Optional base directory for overlay
            cli: Optional CLI instance
        """
        self.agent_id = agent_id or f"test-{uuid.uuid4().hex[:8]}"
        self.base = base
        self.cli = cli or AgentFSCLI()
        self.fs: Optional[FSOperations] = None
        self._initialized = False

    async def __aenter__(self) -> "MockAgent":
        """Create the mock agent."""
        options = InitOptions(base=self.base) if self.base else None
        await self.cli.init(self.agent_id, options=options)
        self.fs = FSOperations(self.agent_id, cli=self.cli)
        self._initialized = True
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Clean up the mock agent."""
        if self._initialized:
            import os
            db_path = Path.home() / ".agentfs" / f"{self.agent_id}.db"
            if db_path.exists():
                try:
                    os.remove(db_path)
                except Exception:
                    pass
        return False

    async def setup_files(self, files: dict[str, str]):
        """Set up test files.

        Args:
            files: Dictionary mapping paths to contents

        Examples:
            >>> await agent.setup_files({
            ...     "/config.json": '{"key": "value"}',
            ...     "/data.txt": "test data"
            ... })
        """
        for path, content in files.items():
            await self.fs.write(path, content)

    async def assert_file_exists(self, path: str):
        """Assert that a file exists.

        Args:
            path: File path to check

        Raises:
            AssertionError: If file doesn't exist
        """
        exists = await self.fs.exists(path)
        assert exists, f"File does not exist: {path}"

    async def assert_file_content(self, path: str, expected: str):
        """Assert file content matches expected.

        Args:
            path: File path
            expected: Expected content

        Raises:
            AssertionError: If content doesn't match
        """
        content = await self.fs.cat(path)
        assert content.strip() == expected.strip(), \
            f"Content mismatch for {path}:\nExpected: {expected}\nActual: {content}"


@asynccontextmanager
async def mock_agent(
    *,
    agent_id: Optional[str] = None,
    base: Optional[Path] = None,
    files: Optional[dict[str, str]] = None
) -> AsyncIterator[MockAgent]:
    """Create a mock agent for testing.

    Args:
        agent_id: Optional agent ID
        base: Optional base directory
        files: Optional files to create

    Yields:
        MockAgent instance

    Examples:
        >>> async with mock_agent(files={"/test.txt": "data"}) as agent:
        ...     content = await agent.fs.cat("/test.txt")
        ...     assert "data" in content
    """
    async with MockAgent(agent_id=agent_id, base=base) as agent:
        if files:
            await agent.setup_files(files)
        yield agent


@asynccontextmanager
async def temp_project(files: Optional[dict[str, str]] = None) -> AsyncIterator[Path]:
    """Create temporary project directory.

    Args:
        files: Optional files to create in project

    Yields:
        Path to temporary project directory

    Examples:
        >>> async with temp_project(files={"README.md": "# Test"}) as project:
        ...     assert (project / "README.md").exists()
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        project_path = Path(tmpdir)

        if files:
            for path, content in files.items():
                file_path = project_path / path.lstrip('/')
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(content)

        yield project_path


class TestHelpers:
    """Collection of test helper functions."""

    @staticmethod
    async def wait_for_condition(
        condition: callable,
        *,
        timeout: float = 5.0,
        interval: float = 0.1
    ) -> bool:
        """Wait for a condition to become true.

        Args:
            condition: Async or sync callable that returns bool
            timeout: Maximum time to wait in seconds
            interval: Check interval in seconds

        Returns:
            True if condition met, False if timeout

        Examples:
            >>> async def file_exists():
            ...     return await agent.fs.exists("/output.txt")
            >>>
            >>> success = await TestHelpers.wait_for_condition(file_exists)
            >>> assert success
        """
        import time
        start = time.time()

        while time.time() - start < timeout:
            if asyncio.iscoroutinefunction(condition):
                result = await condition()
            else:
                result = condition()

            if result:
                return True

            await asyncio.sleep(interval)

        return False

    @staticmethod
    def generate_test_data(
        size: int = 1024,
        pattern: str = "test"
    ) -> str:
        """Generate test data of specified size.

        Args:
            size: Size in bytes
            pattern: Pattern to repeat

        Returns:
            Test data string

        Examples:
            >>> data = TestHelpers.generate_test_data(100)
            >>> assert len(data) >= 100
        """
        repeat_count = (size // len(pattern)) + 1
        return (pattern * repeat_count)[:size]

    @staticmethod
    async def compare_directories(
        path1: Path,
        path2: Path,
        *,
        ignore_timestamps: bool = True
    ) -> tuple[bool, list[str]]:
        """Compare two directories.

        Args:
            path1: First directory
            path2: Second directory
            ignore_timestamps: If True, only compare content

        Returns:
            Tuple of (are_equal, differences)

        Examples:
            >>> equal, diffs = await TestHelpers.compare_directories(
            ...     Path("/original"),
            ...     Path("/copy")
            ... )
            >>> assert equal, f"Differences: {diffs}"
        """
        differences = []

        # Get all files in both directories
        files1 = set(f.relative_to(path1) for f in path1.rglob('*') if f.is_file())
        files2 = set(f.relative_to(path2) for f in path2.rglob('*') if f.is_file())

        # Check for missing files
        only_in_1 = files1 - files2
        only_in_2 = files2 - files1

        for f in only_in_1:
            differences.append(f"Only in {path1}: {f}")
        for f in only_in_2:
            differences.append(f"Only in {path2}: {f}")

        # Compare common files
        for f in files1 & files2:
            file1 = path1 / f
            file2 = path2 / f

            content1 = file1.read_bytes()
            content2 = file2.read_bytes()

            if content1 != content2:
                differences.append(f"Content differs: {f}")

        return len(differences) == 0, differences


class AgentFSTestCase:
    """Base class for AgentFS test cases.

    Provides common setup and teardown for tests.

    Examples:
        >>> class MyTest(AgentFSTestCase):
        ...     async def test_something(self):
        ...         await self.agent.fs.write("/test.txt", "data")
        ...         self.assert_file_exists("/test.txt")
    """

    def setup_method(self):
        """Set up test (called before each test method)."""
        self.agent_id = f"test-{uuid.uuid4().hex[:8]}"
        self.cli = AgentFSCLI()

    def teardown_method(self):
        """Clean up test (called after each test method)."""
        import os
        db_path = Path.home() / ".agentfs" / f"{self.agent_id}.db"
        if db_path.exists():
            try:
                os.remove(db_path)
            except Exception:
                pass

    async def create_agent(
        self,
        *,
        base: Optional[Path] = None
    ) -> FSOperations:
        """Create a test agent.

        Args:
            base: Optional base directory

        Returns:
            FSOperations for the agent
        """
        options = InitOptions(base=base) if base else None
        await self.cli.init(self.agent_id, options=options)
        return FSOperations(self.agent_id, cli=self.cli)

    def assert_file_exists(self, fs: FSOperations, path: str):
        """Assert file exists."""
        assert asyncio.run(fs.exists(path)), f"File not found: {path}"
```

### 16.2 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.testing import (
    MockAgent,
    mock_agent,
    temp_project,
    TestHelpers,
    AgentFSTestCase,
)

__all__ = [
    # ... existing ...
    "MockAgent",
    "mock_agent",
    "temp_project",
    "TestHelpers",
    "AgentFSTestCase",
]
```

### 16.3 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_testing_utilities.py`:

```python
"""Tests for testing utilities."""

import pytest
from pathlib import Path

from agentfs_pydantic.testing import (
    MockAgent,
    mock_agent,
    temp_project,
    TestHelpers,
)


class TestMockAgent:
    """Tests for MockAgent."""

    @pytest.mark.asyncio
    async def test_mock_agent_context(self):
        """Test mock agent context manager."""
        async with MockAgent() as agent:
            assert agent.fs is not None
            await agent.fs.write("/test.txt", "data")
            assert await agent.fs.exists("/test.txt")

    @pytest.mark.asyncio
    async def test_setup_files(self):
        """Test setting up files."""
        async with mock_agent() as agent:
            await agent.setup_files({
                "/file1.txt": "content1",
                "/file2.txt": "content2"
            })

            assert await agent.fs.exists("/file1.txt")
            assert await agent.fs.exists("/file2.txt")

    @pytest.mark.asyncio
    async def test_assertions(self):
        """Test assertion helpers."""
        async with mock_agent() as agent:
            await agent.fs.write("/test.txt", "test content")

            await agent.assert_file_exists("/test.txt")
            await agent.assert_file_content("/test.txt", "test content")


class TestTempProject:
    """Tests for temp_project."""

    @pytest.mark.asyncio
    async def test_temp_project_creation(self):
        """Test creating temporary project."""
        async with temp_project() as project:
            assert project.exists()
            assert project.is_dir()

    @pytest.mark.asyncio
    async def test_temp_project_with_files(self):
        """Test creating project with files."""
        async with temp_project(files={
            "README.md": "# Test",
            "src/main.py": "print('hello')"
        }) as project:
            assert (project / "README.md").exists()
            assert (project / "src" / "main.py").exists()


class TestHelpers:
    """Tests for TestHelpers."""

    @pytest.mark.asyncio
    async def test_wait_for_condition(self):
        """Test waiting for condition."""
        import time
        start = time.time()

        async def condition():
            return time.time() - start > 0.2

        result = await TestHelpers.wait_for_condition(condition)
        assert result is True

    def test_generate_test_data(self):
        """Test test data generation."""
        data = TestHelpers.generate_test_data(100)
        assert len(data) == 100

        data = TestHelpers.generate_test_data(50, pattern="abc")
        assert len(data) == 50
        assert all(c in "abc" for c in data)
```

## Testing

### Manual Testing

```python
import asyncio
from agentfs_pydantic.testing import mock_agent, temp_project, TestHelpers

async def main():
    # Test 1: Mock agent
    print("1. Testing mock agent...")
    async with mock_agent(files={"/test.txt": "data"}) as agent:
        content = await agent.fs.cat("/test.txt")
        print(f"Content: {content}")
        await agent.assert_file_content("/test.txt", "data")
    print("Mock agent cleaned up")

    # Test 2: Temp project
    print("\n2. Testing temp project...")
    async with temp_project(files={"README.md": "# Test"}) as project:
        print(f"Project at: {project}")
        print(f"README exists: {(project / 'README.md').exists()}")

    # Test 3: Test helpers
    print("\n3. Testing helpers...")
    data = TestHelpers.generate_test_data(50)
    print(f"Generated {len(data)} bytes of test data")

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_testing_utilities.py -v
```

## Success Criteria

- [ ] MockAgent provides clean test agents
- [ ] mock_agent context manager works
- [ ] temp_project creates temporary projects
- [ ] TestHelpers provides useful utilities
- [ ] AgentFSTestCase base class works
- [ ] Assertion helpers work
- [ ] Test data generation works
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Agent cleanup fails
- **Solution**: Use best-effort cleanup in finally blocks

**Issue**: Tests interfere with each other
- **Solution**: Each test gets unique agent ID

**Issue**: Temp files not cleaned up
- **Solution**: Use context managers consistently

## Next Steps

Once this step is complete:
1. Proceed to [Step 17: High-Level Convenience APIs](./DEV_GUIDE-STEP_17.md)
2. Testing utilities make development much easier

## Design Notes

- All test helpers are async context managers
- Automatic cleanup is guaranteed
- Unique agent IDs prevent conflicts
- Assertion helpers provide clear error messages
- Test data generation supports various patterns
- Directory comparison useful for overlay testing
