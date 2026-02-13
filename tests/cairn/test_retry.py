"""Unit tests for RetryStrategy.

Tests implement contracts from ROADMAP-STEP_2.md.
"""

import pytest

from cairn.retry import RetryStrategy


class TestRetryStrategy:
    """Test retry logic."""

    @pytest.mark.asyncio
    async def test_retry_on_failure(self):
        """Contract 1: Retry on failure."""
        attempts = []

        async def failing_operation():
            attempts.append(1)
            if len(attempts) < 3:
                raise ValueError("Not yet")
            return "success"

        retry = RetryStrategy(max_attempts=3, initial_delay=0.01)
        result = await retry.with_retry(failing_operation)

        assert result == "success"
        assert len(attempts) == 3

    @pytest.mark.asyncio
    async def test_give_up_after_max_attempts(self):
        """Contract 2: Give up after max attempts."""

        async def always_fails():
            raise ValueError("Always fails")

        retry = RetryStrategy(max_attempts=3, initial_delay=0.01)

        with pytest.raises(ValueError, match="Always fails"):
            await retry.with_retry(always_fails)

    @pytest.mark.asyncio
    async def test_error_handler_called(self):
        """Contract 3: Error handler called on each failure."""
        errors = []

        async def failing_operation():
            raise ValueError("Failure")

        async def error_handler(e: Exception, attempt: int):
            errors.append((str(e), attempt))

        retry = RetryStrategy(max_attempts=3, initial_delay=0.01)

        with pytest.raises(ValueError):
            await retry.with_retry(failing_operation, error_handler)

        assert len(errors) == 3
        assert errors[0][1] == 0  # First attempt
        assert errors[1][1] == 1  # Second attempt
        assert errors[2][1] == 2  # Third attempt

    @pytest.mark.asyncio
    async def test_successful_first_attempt(self):
        """Test immediate success without retries."""

        async def immediate_success():
            return "success"

        retry = RetryStrategy(max_attempts=3)
        result = await retry.with_retry(immediate_success)

        assert result == "success"

    @pytest.mark.asyncio
    async def test_exponential_backoff(self):
        """Test that delays increase exponentially."""
        retry = RetryStrategy(
            max_attempts=4, initial_delay=1.0, backoff_factor=2.0, max_delay=100.0
        )

        # Calculate delays
        assert retry._calculate_delay(0) == 1.0  # 1.0 * 2^0
        assert retry._calculate_delay(1) == 2.0  # 1.0 * 2^1
        assert retry._calculate_delay(2) == 4.0  # 1.0 * 2^2
        assert retry._calculate_delay(3) == 8.0  # 1.0 * 2^3

    @pytest.mark.asyncio
    async def test_max_delay_enforced(self):
        """Test that max delay is not exceeded."""
        retry = RetryStrategy(
            max_attempts=10, initial_delay=1.0, backoff_factor=2.0, max_delay=5.0
        )

        # Even for high attempt numbers, delay should not exceed max_delay
        assert retry._calculate_delay(10) == 5.0

    @pytest.mark.asyncio
    async def test_retry_specific_exceptions(self):
        """Test retrying only specific exception types."""
        attempts = []

        async def operation():
            attempts.append(1)
            if len(attempts) < 2:
                raise ValueError("Retry this")
            raise TypeError("Don't retry this")

        retry = RetryStrategy(max_attempts=5, initial_delay=0.01)

        with pytest.raises(TypeError, match="Don't retry this"):
            await retry.with_retry(operation, retry_exceptions=(ValueError,))

        # Should have attempted twice (first ValueError, then TypeError)
        assert len(attempts) == 2
