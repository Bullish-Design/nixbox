"""Pytest fixtures for Cairn tests."""

import pytest
from agentfs_sdk import AgentFS
from agentfs_pydantic import AgentFSOptions


@pytest.fixture
async def stable_fs():
    """Create temporary stable filesystem."""
    fs = await AgentFS.open(AgentFSOptions(id="test-stable").model_dump())
    yield fs
    await fs.close()


@pytest.fixture
async def agent_fs():
    """Create temporary agent filesystem."""
    fs = await AgentFS.open(AgentFSOptions(id="test-agent").model_dump())
    yield fs
    await fs.close()


@pytest.fixture
def mock_llm_provider():
    """Create mock LLM provider for testing."""

    class MockLLMProvider:
        def __init__(self):
            self.calls = []

        async def generate(self, prompt: str) -> str:
            self.calls.append(prompt)
            # Return simple mock response
            return "mock response"

    return MockLLMProvider()
