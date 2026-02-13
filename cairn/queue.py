"""Priority task queue for orchestrated agent work."""

from __future__ import annotations

import asyncio
import heapq
import time
from dataclasses import dataclass, field
from enum import Enum


class TaskPriority(int, Enum):
    """Task scheduling priority."""

    LOW = 1
    NORMAL = 2
    HIGH = 3
    URGENT = 4


@dataclass(order=True)
class QueuedTask:
    """Task entry stored in the orchestrator queue."""

    _sort_key: tuple[int, float] = field(init=False, repr=False)
    task: str = field(compare=False)
    priority: TaskPriority = field(default=TaskPriority.NORMAL, compare=False)
    created_at: float = field(default_factory=time.time, compare=False)

    def __post_init__(self) -> None:
        self._sort_key = (-int(self.priority), self.created_at)


class TaskQueue:
    """Priority queue with max-concurrency gating and completion tracking."""

    def __init__(self, max_concurrent: int = 5):
        self.max_concurrent = max_concurrent
        self._queue: list[QueuedTask] = []
        self.active_count = 0
        self.completed_count = 0
        self._lock = asyncio.Lock()

    async def enqueue(self, task: str, priority: TaskPriority = TaskPriority.NORMAL) -> None:
        """Add task to queue."""
        queued_task = QueuedTask(task=task, priority=priority)
        async with self._lock:
            heapq.heappush(self._queue, queued_task)

    async def dequeue(self) -> QueuedTask | None:
        """Get next task unless queue empty or active tasks hit max concurrency."""
        async with self._lock:
            if self.active_count >= self.max_concurrent or not self._queue:
                return None

            task = heapq.heappop(self._queue)
            self.active_count += 1
            return task

    def mark_complete(self, task: QueuedTask | None = None) -> None:
        """Mark a running task complete and release concurrency slot."""
        if self.active_count > 0:
            self.active_count -= 1
            self.completed_count += 1

    def size(self) -> int:
        """Get current queue size."""
        return len(self._queue)
