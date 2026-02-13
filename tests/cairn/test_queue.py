"""Stage 3 unit tests for queue priority and concurrency behavior."""

from __future__ import annotations

import pytest

from cairn.queue import TaskPriority, TaskQueue


@pytest.mark.asyncio
async def test_queue_dequeues_by_priority_order() -> None:
    queue = TaskQueue()

    await queue.enqueue("low", TaskPriority.LOW)
    await queue.enqueue("urgent", TaskPriority.URGENT)
    await queue.enqueue("high", TaskPriority.HIGH)

    first = await queue.dequeue()
    second = await queue.dequeue()
    third = await queue.dequeue()

    assert first is not None and first.priority == TaskPriority.URGENT
    assert second is not None and second.priority == TaskPriority.HIGH
    assert third is not None and third.priority == TaskPriority.LOW


@pytest.mark.asyncio
async def test_queue_respects_max_concurrency_gate() -> None:
    queue = TaskQueue(max_concurrent=1)

    await queue.enqueue("task-1")
    await queue.enqueue("task-2")

    assert await queue.dequeue() is not None
    assert await queue.dequeue() is None

    queue.mark_complete()

    next_task = await queue.dequeue()
    assert next_task is not None
    assert next_task.task == "task-2"


@pytest.mark.asyncio
async def test_queue_completion_bookkeeping() -> None:
    queue = TaskQueue(max_concurrent=2)

    await queue.enqueue("task-1")
    await queue.enqueue("task-2")

    assert await queue.dequeue() is not None
    assert await queue.dequeue() is not None
    assert queue.active_count == 2

    queue.mark_complete()
    queue.mark_complete()

    assert queue.active_count == 0
    assert queue.completed_count == 2
