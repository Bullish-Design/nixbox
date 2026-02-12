# Step 15: Observer/Event System

**Phase**: 4 - Quality
**Difficulty**: Medium
**Estimated Time**: 3-4 hours
**Prerequisites**: Phase 3 (Steps 1-14)

## Objective

Implement an event system for observability and monitoring:
- Event types for all major operations
- Observer pattern for event handlers
- Async event emission
- Built-in logging and metrics
- Debug and monitoring support

## Why This Matters

Event system enables:
- Monitoring AgentFS operations
- Debugging complex workflows
- Performance tracking
- Custom instrumentation
- Integration with monitoring tools

## Implementation Guide

### 15.1 Create Observer Module

Create `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/observer.py`:

```python
"""Event observer system for AgentFS operations."""

from typing import Callable, Any, Optional
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
import asyncio
from collections import defaultdict


class EventType(str, Enum):
    """Types of events emitted by AgentFS operations."""

    # Lifecycle events
    AGENT_INIT = "agent.init"
    AGENT_DESTROY = "agent.destroy"

    # Filesystem events
    FILE_READ = "file.read"
    FILE_WRITE = "file.write"
    FILE_DELETE = "file.delete"
    DIR_CREATE = "dir.create"
    DIR_LIST = "dir.list"

    # Mount events
    MOUNT_START = "mount.start"
    MOUNT_STOP = "mount.stop"

    # Server events
    SERVER_START = "server.start"
    SERVER_STOP = "server.stop"

    # Sync events
    SYNC_PULL = "sync.pull"
    SYNC_PUSH = "sync.push"

    # Command events
    COMMAND_START = "command.start"
    COMMAND_END = "command.end"
    COMMAND_ERROR = "command.error"

    # Migration events
    MIGRATION_START = "migration.start"
    MIGRATION_END = "migration.end"


@dataclass
class Event:
    """Base event class.

    Examples:
        >>> event = Event(
        ...     type=EventType.FILE_WRITE,
        ...     agent_id="my-agent",
        ...     data={"path": "/file.txt", "size": 100}
        ... )
    """

    type: EventType
    timestamp: datetime
    agent_id: Optional[str] = None
    data: dict[str, Any] = None
    duration_ms: Optional[float] = None
    error: Optional[str] = None

    def __post_init__(self):
        """Initialize data dict."""
        if self.data is None:
            self.data = {}

    def __str__(self) -> str:
        """Format event as string."""
        parts = [f"[{self.type.value}]"]
        if self.agent_id:
            parts.append(f"agent={self.agent_id}")
        if self.duration_ms:
            parts.append(f"duration={self.duration_ms:.2f}ms")
        if self.error:
            parts.append(f"error={self.error}")
        if self.data:
            data_str = ", ".join(f"{k}={v}" for k, v in self.data.items())
            parts.append(data_str)
        return " ".join(parts)


EventHandler = Callable[[Event], None]
AsyncEventHandler = Callable[[Event], asyncio.Future]


class EventEmitter:
    """Event emitter for AgentFS operations.

    Examples:
        >>> emitter = EventEmitter()
        >>>
        >>> # Register handler
        >>> @emitter.on(EventType.FILE_WRITE)
        ... def handle_write(event):
        ...     print(f"File written: {event.data['path']}")
        >>>
        >>> # Emit event
        >>> emitter.emit(Event(
        ...     type=EventType.FILE_WRITE,
        ...     agent_id="my-agent",
        ...     data={"path": "/test.txt"}
        ... ))
    """

    def __init__(self):
        """Initialize emitter."""
        self._handlers: dict[EventType, list[EventHandler]] = defaultdict(list)
        self._async_handlers: dict[EventType, list[AsyncEventHandler]] = defaultdict(list)
        self._global_handlers: list[EventHandler] = []
        self._global_async_handlers: list[AsyncEventHandler] = []

    def on(
        self,
        event_type: Optional[EventType] = None,
        *,
        async_handler: bool = False
    ):
        """Decorator to register event handler.

        Args:
            event_type: Event type to handle (None = all events)
            async_handler: If True, handler is async

        Examples:
            >>> @emitter.on(EventType.FILE_WRITE)
            ... def handle_write(event):
            ...     print(f"Write: {event.data['path']}")
            >>>
            >>> @emitter.on(EventType.COMMAND_START, async_handler=True)
            ... async def handle_command(event):
            ...     await log_to_db(event)
        """
        def decorator(handler):
            self.register(handler, event_type, async_handler=async_handler)
            return handler
        return decorator

    def register(
        self,
        handler: Callable,
        event_type: Optional[EventType] = None,
        *,
        async_handler: bool = False
    ):
        """Register an event handler.

        Args:
            handler: Handler function
            event_type: Event type to handle (None = all events)
            async_handler: If True, handler is async
        """
        if event_type is None:
            # Global handler
            if async_handler:
                self._global_async_handlers.append(handler)
            else:
                self._global_handlers.append(handler)
        else:
            # Specific event type
            if async_handler:
                self._async_handlers[event_type].append(handler)
            else:
                self._handlers[event_type].append(handler)

    def emit(self, event: Event):
        """Emit an event synchronously.

        Args:
            event: Event to emit
        """
        # Call specific handlers
        for handler in self._handlers.get(event.type, []):
            try:
                handler(event)
            except Exception:
                # Don't let handler errors break execution
                pass

        # Call global handlers
        for handler in self._global_handlers:
            try:
                handler(event)
            except Exception:
                pass

    async def emit_async(self, event: Event):
        """Emit an event asynchronously.

        Args:
            event: Event to emit
        """
        # Call sync handlers first
        self.emit(event)

        # Call async handlers
        tasks = []

        for handler in self._async_handlers.get(event.type, []):
            tasks.append(asyncio.create_task(handler(event)))

        for handler in self._global_async_handlers:
            tasks.append(asyncio.create_task(handler(event)))

        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)


class BuiltinHandlers:
    """Built-in event handlers for common use cases."""

    @staticmethod
    def console_logger(verbose: bool = False) -> EventHandler:
        """Create console logging handler.

        Args:
            verbose: If True, log all events

        Returns:
            Event handler function

        Examples:
            >>> emitter = EventEmitter()
            >>> emitter.register(BuiltinHandlers.console_logger(verbose=True))
        """
        def handler(event: Event):
            if verbose or event.error:
                print(f"{event.timestamp.isoformat()} {event}")
        return handler

    @staticmethod
    def error_collector() -> tuple[EventHandler, Callable[[], list[Event]]]:
        """Create error collection handler.

        Returns:
            Tuple of (handler, getter function)

        Examples:
            >>> handler, get_errors = BuiltinHandlers.error_collector()
            >>> emitter.register(handler)
            >>> # ... operations ...
            >>> errors = get_errors()
            >>> print(f"Collected {len(errors)} errors")
        """
        errors = []

        def handler(event: Event):
            if event.error:
                errors.append(event)

        def get_errors() -> list[Event]:
            return errors.copy()

        return handler, get_errors

    @staticmethod
    def metrics_collector() -> tuple[EventHandler, Callable[[], dict]]:
        """Create metrics collection handler.

        Returns:
            Tuple of (handler, getter function)

        Examples:
            >>> handler, get_metrics = BuiltinHandlers.metrics_collector()
            >>> emitter.register(handler)
            >>> # ... operations ...
            >>> metrics = get_metrics()
            >>> print(f"Total events: {metrics['total_events']}")
        """
        metrics = defaultdict(int)
        durations = defaultdict(list)

        def handler(event: Event):
            metrics['total_events'] += 1
            metrics[f'type_{event.type.value}'] += 1

            if event.error:
                metrics['total_errors'] += 1

            if event.duration_ms:
                durations[event.type].append(event.duration_ms)

        def get_metrics() -> dict:
            result = dict(metrics)

            # Add average durations
            for event_type, values in durations.items():
                if values:
                    result[f'avg_duration_{event_type.value}'] = sum(values) / len(values)

            return result

        return handler, get_metrics


# Global default emitter
_default_emitter = EventEmitter()


def get_default_emitter() -> EventEmitter:
    """Get the global default event emitter."""
    return _default_emitter


def set_default_emitter(emitter: EventEmitter):
    """Set the global default event emitter."""
    global _default_emitter
    _default_emitter = emitter
```

### 15.2 Integrate Events with CLI Operations

Update `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/cli.py`:

```python
from agentfs_pydantic.observer import EventEmitter, Event, EventType, get_default_emitter
import time

class AgentFSCLI:
    def __init__(
        self,
        binary_path: Optional[Path] = None,
        *,
        emitter: Optional[EventEmitter] = None
    ):
        """Initialize CLI wrapper.

        Args:
            binary_path: Optional explicit path to agentfs binary
            emitter: Optional event emitter (uses global if None)
        """
        self.binary = AgentFSBinary(binary_path=binary_path)
        self.emitter = emitter or get_default_emitter()

    async def init(self, agent_id: str, *, options: Optional["InitOptions"] = None):
        """Initialize agent with event emission."""
        start_time = time.perf_counter()

        try:
            # Emit start event
            self.emitter.emit(Event(
                type=EventType.AGENT_INIT,
                timestamp=datetime.now(),
                agent_id=agent_id,
                data={"options": options.model_dump() if options else {}}
            ))

            # Perform operation
            result = await self._init_impl(agent_id, options=options)

            # Emit end event
            duration = (time.perf_counter() - start_time) * 1000
            self.emitter.emit(Event(
                type=EventType.COMMAND_END,
                timestamp=datetime.now(),
                agent_id=agent_id,
                duration_ms=duration,
                data={"command": "init", "success": result.success}
            ))

            return result

        except Exception as e:
            # Emit error event
            duration = (time.perf_counter() - start_time) * 1000
            self.emitter.emit(Event(
                type=EventType.COMMAND_ERROR,
                timestamp=datetime.now(),
                agent_id=agent_id,
                duration_ms=duration,
                error=str(e),
                data={"command": "init"}
            ))
            raise

    async def _init_impl(self, agent_id: str, *, options: Optional["InitOptions"] = None):
        """Actual init implementation (existing code)."""
        # Move existing init logic here
        pass
```

### 15.3 Update Exports

Add to `/home/user/nixbox/agentfs-pydantic/src/agentfs_pydantic/__init__.py`:

```python
from agentfs_pydantic.observer import (
    EventEmitter,
    Event,
    EventType,
    BuiltinHandlers,
    get_default_emitter,
    set_default_emitter,
)

__all__ = [
    # ... existing ...
    "EventEmitter",
    "Event",
    "EventType",
    "BuiltinHandlers",
    "get_default_emitter",
    "set_default_emitter",
]
```

### 15.4 Create Tests

Create `/home/user/nixbox/agentfs-pydantic/tests/test_observer.py`:

```python
"""Tests for event system."""

import pytest
from datetime import datetime

from agentfs_pydantic.observer import (
    EventEmitter,
    Event,
    EventType,
    BuiltinHandlers,
)


class TestEventEmitter:
    """Tests for event emitter."""

    def test_basic_emission(self):
        """Test basic event emission."""
        emitter = EventEmitter()
        events_received = []

        @emitter.on(EventType.FILE_WRITE)
        def handler(event):
            events_received.append(event)

        event = Event(
            type=EventType.FILE_WRITE,
            timestamp=datetime.now(),
            agent_id="test",
            data={"path": "/test.txt"}
        )

        emitter.emit(event)
        assert len(events_received) == 1
        assert events_received[0] == event

    def test_multiple_handlers(self):
        """Test multiple handlers for same event."""
        emitter = EventEmitter()
        call_count = [0]

        @emitter.on(EventType.FILE_READ)
        def handler1(event):
            call_count[0] += 1

        @emitter.on(EventType.FILE_READ)
        def handler2(event):
            call_count[0] += 1

        emitter.emit(Event(
            type=EventType.FILE_READ,
            timestamp=datetime.now()
        ))

        assert call_count[0] == 2

    def test_global_handler(self):
        """Test global handler receives all events."""
        emitter = EventEmitter()
        events_received = []

        @emitter.on()  # No event type = global
        def global_handler(event):
            events_received.append(event)

        emitter.emit(Event(type=EventType.FILE_WRITE, timestamp=datetime.now()))
        emitter.emit(Event(type=EventType.FILE_READ, timestamp=datetime.now()))

        assert len(events_received) == 2

    @pytest.mark.asyncio
    async def test_async_handler(self):
        """Test async event handlers."""
        emitter = EventEmitter()
        events_received = []

        @emitter.on(EventType.SYNC_PULL, async_handler=True)
        async def async_handler(event):
            events_received.append(event)

        event = Event(type=EventType.SYNC_PULL, timestamp=datetime.now())
        await emitter.emit_async(event)

        assert len(events_received) == 1


class TestBuiltinHandlers:
    """Tests for built-in handlers."""

    def test_error_collector(self):
        """Test error collection."""
        emitter = EventEmitter()
        handler, get_errors = BuiltinHandlers.error_collector()
        emitter.register(handler)

        # Emit normal event
        emitter.emit(Event(type=EventType.FILE_READ, timestamp=datetime.now()))

        # Emit error event
        emitter.emit(Event(
            type=EventType.COMMAND_ERROR,
            timestamp=datetime.now(),
            error="Test error"
        ))

        errors = get_errors()
        assert len(errors) == 1
        assert errors[0].error == "Test error"

    def test_metrics_collector(self):
        """Test metrics collection."""
        emitter = EventEmitter()
        handler, get_metrics = BuiltinHandlers.metrics_collector()
        emitter.register(handler)

        # Emit some events
        emitter.emit(Event(type=EventType.FILE_WRITE, timestamp=datetime.now()))
        emitter.emit(Event(type=EventType.FILE_WRITE, timestamp=datetime.now()))
        emitter.emit(Event(type=EventType.FILE_READ, timestamp=datetime.now()))

        metrics = get_metrics()
        assert metrics['total_events'] == 3
        assert metrics['type_file.write'] == 2
        assert metrics['type_file.read'] == 1
```

## Testing

### Manual Testing

```python
import asyncio
from agentfs_pydantic import (
    EventEmitter,
    Event,
    EventType,
    BuiltinHandlers,
    AgentFSCLI,
    InitOptions,
)

async def main():
    # Create emitter with handlers
    emitter = EventEmitter()

    # Add console logger
    emitter.register(BuiltinHandlers.console_logger(verbose=True))

    # Add error collector
    error_handler, get_errors = BuiltinHandlers.error_collector()
    emitter.register(error_handler)

    # Add metrics collector
    metrics_handler, get_metrics = BuiltinHandlers.metrics_collector()
    emitter.register(metrics_handler)

    # Custom handler
    @emitter.on(EventType.FILE_WRITE)
    def on_file_write(event):
        print(f"Custom handler: File written to {event.data.get('path')}")

    # Use CLI with emitter
    cli = AgentFSCLI(emitter=emitter)
    await cli.init("event-demo", options=InitOptions(force=True))

    # Check metrics
    print("\nMetrics:")
    print(get_metrics())

    print("\nErrors:")
    print(get_errors())

asyncio.run(main())
```

### Automated Testing

```bash
cd /home/user/nixbox/agentfs-pydantic
uv run pytest tests/test_observer.py -v
```

## Success Criteria

- [ ] Event system created with EventEmitter
- [ ] Event types defined for all operations
- [ ] Handlers can be registered/unregistered
- [ ] Both sync and async handlers work
- [ ] Global handlers receive all events
- [ ] Built-in handlers (console, errors, metrics) work
- [ ] CLI operations emit events
- [ ] All tests pass
- [ ] Exports added to `__init__.py`

## Common Issues

**Issue**: Handler exceptions break execution
- **Solution**: Handlers are wrapped in try/except

**Issue**: Too many events
- **Solution**: Use specific event types, not global

**Issue**: Async handler not called
- **Solution**: Use emit_async, not emit

## Next Steps

Once this step is complete:
1. Proceed to [Step 16: Testing Utilities](./DEV_GUIDE-STEP_16.md)
2. Events enable better debugging and monitoring

## Design Notes

- Observer pattern for loose coupling
- Both sync and async handlers supported
- Built-in handlers for common cases
- Global default emitter for convenience
- Events don't affect operation success
- Handler errors are suppressed
