"""Tests for rate limiter functionality."""

import pytest
import asyncio
import time as time_module
from unittest.mock import patch
from app.services.rate_limiter import RateLimiter, check_rate_limit, get_rate_limit_status


class TestRateLimiter:
    """Test cases for RateLimiter class."""

    @pytest.fixture
    def rate_limiter(self):
        """Create a rate limiter instance for testing."""
        limiter = RateLimiter(requests_per_minute=2, requests_per_hour=10)
        # Mock time for testing
        limiter.set_time_func(time_module.time)
        return limiter

    @pytest.mark.asyncio
    async def test_initial_state(self, rate_limiter):
        """Test that rate limiter allows requests initially."""
        # Use different clients for each test to avoid interference
        assert await rate_limiter.is_allowed("initial_client_1") is True
        assert await rate_limiter.is_allowed("initial_client_2") is True
        assert await rate_limiter.is_allowed("initial_client_3") is True

    @pytest.mark.asyncio
    async def test_minute_limit(self, rate_limiter):
        """Test minute rate limiting."""
        client_id = "test_client"

        # Allow initial requests
        assert await rate_limiter.is_allowed(client_id) is True
        assert await rate_limiter.is_allowed(client_id) is True

        # Should block third request
        assert await rate_limiter.is_allowed(client_id) is False

    @pytest.mark.asyncio
    async def test_different_clients(self, rate_limiter):
        """Test that rate limiting is per-client."""
        # Client 1 makes 2 requests (limit)
        assert await rate_limiter.is_allowed("client1") is True
        assert await rate_limiter.is_allowed("client1") is True
        assert await rate_limiter.is_allowed("client1") is False

        # Client 2 should still be able to make requests
        assert await rate_limiter.is_allowed("client2") is True
        assert await rate_limiter.is_allowed("client2") is True

    @pytest.mark.asyncio
    async def test_time_window_reset(self, rate_limiter):
        """Test that requests are tracked properly over time."""
        client_id = "time_test_client"

        # Make 2 requests
        assert await rate_limiter.is_allowed(client_id) is True
        assert await rate_limiter.is_allowed(client_id) is True

        # Should be blocked now
        assert await rate_limiter.is_allowed(client_id) is False

        # Check remaining requests
        remaining = await rate_limiter.get_remaining_requests(client_id)
        assert remaining["per_minute"] == 0
        assert remaining["per_hour"] == 8  # 2 requests used out of 10

    @pytest.mark.asyncio
    async def test_get_remaining_requests(self, rate_limiter):
        """Test getting remaining requests count."""
        client_id = "remaining_test"

        # Check initial state
        remaining = await rate_limiter.get_remaining_requests(client_id)
        assert remaining["per_minute"] == 2
        assert remaining["per_hour"] == 10

        # Make one request
        await rate_limiter.is_allowed(client_id)

        # Check remaining
        remaining = await rate_limiter.get_remaining_requests(client_id)
        assert remaining["per_minute"] == 1
        assert remaining["per_hour"] == 9

    @pytest.mark.asyncio
    async def test_hour_limit(self, rate_limiter):
        """Test hourly rate limiting."""
        client_id = "hour_test_client"

        # Make 2 requests (minute limit)
        assert await rate_limiter.is_allowed(client_id) is True
        assert await rate_limiter.is_allowed(client_id) is True

        # Should be blocked for minute limit now
        assert await rate_limiter.is_allowed(client_id) is False

        # Make 8 more clients with 2 requests each (total 10 requests per hour)
        for i in range(8):
            client = f"hour_test_client_{i}"
            assert await rate_limiter.is_allowed(client) is True
            assert await rate_limiter.is_allowed(client) is True
            if i < 7:  # Last client will be blocked
                assert await rate_limiter.is_allowed(client) is False

    @pytest.mark.asyncio
    async def test_concurrent_requests(self, rate_limiter):
        """Test rate limiter with concurrent requests."""
        client_id = "concurrent_client"

        # Make multiple concurrent requests
        tasks = []
        for _ in range(5):
            tasks.append(rate_limiter.is_allowed(client_id))

        results = await asyncio.gather(*tasks)

        # Should allow 2 requests and block 3
        assert sum(results) == 2


@pytest.mark.asyncio
async def test_check_rate_limit():
    """Test convenience function check_rate_limit."""
    # Test with a new limiter instance
    limiter = RateLimiter(requests_per_minute=60, requests_per_hour=1000)
    result = await limiter.is_allowed("test_client")
    assert isinstance(result, bool)


@pytest.mark.asyncio
async def test_get_rate_limit_status():
    """Test convenience function get_rate_limit_status."""
    # Test with a new limiter instance
    limiter = RateLimiter(requests_per_minute=60, requests_per_hour=1000)
    result = await limiter.get_remaining_requests("test_client")
    assert isinstance(result, dict)
    assert "per_minute" in result
    assert "per_hour" in result