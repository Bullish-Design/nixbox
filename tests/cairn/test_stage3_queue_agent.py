"""Stage 3 unit tests for queue and agent lifecycle primitives."""

import time
from types import SimpleNamespace

import pytest

from cairn.agent import AgentContext, AgentState
from cairn.queue import TaskPriority, TaskQueue


@pytest.mark.asyncio
async def test_priority_ordering() -> None:
    queue = TaskQueue()

    await queue.enqueue("Low task", TaskPriority.LOW)
    await queue.enqueue("High task", TaskPriority.HIGH)
    await queue.enqueue("Normal task", TaskPriority.NORMAL)

    task1 = await queue.dequeue()
    task2 = await queue.dequeue()
    task3 = await queue.dequeue()

    assert task1 is not None
    assert task2 is not None
    assert task3 is not None
    assert task1.priority == TaskPriority.HIGH
    assert task2.priority == TaskPriority.NORMAL
    assert task3.priority == TaskPriority.LOW


@pytest.mark.asyncio
async def test_max_concurrency() -> None:
    queue = TaskQueue(max_concurrent=2)

    await queue.enqueue("Task 1")
    await queue.enqueue("Task 2")
    await queue.enqueue("Task 3")

    assert await queue.dequeue() is not None
    assert await queue.dequeue() is not None
    assert await queue.dequeue() is None


@pytest.mark.asyncio
async def test_active_count_bookkeeping() -> None:
    queue = TaskQueue()

    await queue.enqueue("Task 1")
    task = await queue.dequeue()

    assert task is not None
    assert queue.active_count == 1

    queue.mark_complete(task)
    assert queue.active_count == 0
    assert queue.completed_count == 1


def test_state_timestamp_updated() -> None:
    ctx = AgentContext(
        agent_id="test",
        task="Test",
        priority=TaskPriority.NORMAL,
        state=AgentState.QUEUED,
        agent_fs=SimpleNamespace(),
    )

    t1 = ctx.state_changed_at
    time.sleep(0.01)
    ctx.transition(AgentState.SPAWNING)

    assert ctx.state == AgentState.SPAWNING
    assert ctx.state_changed_at > t1
