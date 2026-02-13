"""Unit tests for queue priority behavior."""

from __future__ import annotations

import asyncio

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
async def test_queue_dequeue_returns_none_when_empty() -> None:
    queue = TaskQueue()

    assert await queue.dequeue() is None


@pytest.mark.asyncio
async def test_dequeue_wait_blocks_until_task_available() -> None:
    queue = TaskQueue()

    waiter = asyncio.create_task(queue.dequeue_wait())
    await asyncio.sleep(0.02)
    await queue.enqueue("task-1")

    dequeued = await waiter
    assert dequeued.task == "task-1"
