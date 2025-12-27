"""Rate limiting service for LLM endpoints."""

import asyncio
import time
from typing import Dict, Optional
from collections import defaultdict, deque
import logging

from app.config import settings

logger = logging.getLogger(__name__)


class RateLimiter:
    """Simple in-memory rate limiter using sliding window algorithm."""

    def __init__(self, requests_per_minute: int = None, requests_per_hour: int = None):
        """
        Initialize rate limiter.

        Args:
            requests_per_minute: Maximum requests per minute per client
            requests_per_hour: Maximum requests per hour per client
        """
        self.requests_per_minute = requests_per_minute or settings.rate_limit_requests_per_minute
        self.requests_per_hour = requests_per_hour or settings.rate_limit_requests_per_hour
        self.requests: Dict[str, deque] = defaultdict(deque)
        self.lock = asyncio.Lock()
        # Allow time injection for testing
        self._time_func = time.time

    async def is_allowed(self, client_id: str) -> bool:
        """
        Check if client is allowed to make a request.

        Args:
            client_id: Unique identifier for client (IP address or API key)

        Returns:
            True if request is allowed, False if rate limited
        """
        async with self.lock:
            now = self._time_func()

            # Clean old requests (older than 1 hour)
            while self.requests[client_id] and now - self.requests[client_id][0] > 3600:
                self.requests[client_id].popleft()

            # Check hourly limit
            if len(self.requests[client_id]) >= self.requests_per_hour:
                logger.warning(f"Rate limit exceeded for client {client_id}: hourly limit")
                return False

            # Count requests in last minute
            minute_requests = sum(1 for req_time in self.requests[client_id]
                               if now - req_time <= 60)

            # Check minute limit
            if minute_requests >= self.requests_per_minute:
                logger.warning(f"Rate limit exceeded for client {client_id}: minute limit")
                return False

            # Add current request
            self.requests[client_id].append(now)
            return True

    def set_time_func(self, time_func):
        """Set time function for testing."""
        self._time_func = time_func

    async def get_remaining_requests(self, client_id: str) -> Dict[str, int]:
        """
        Get remaining requests for client.

        Args:
            client_id: Unique identifier for the client

        Returns:
            Dictionary with remaining requests for minute and hour
        """
        async with self.lock:
            now = self._time_func()

            # Clean old requests
            while self.requests[client_id] and now - self.requests[client_id][0] > 3600:
                self.requests[client_id].popleft()

            # Count requests in last minute
            minute_requests = sum(1 for req_time in self.requests[client_id]
                               if now - req_time <= 60)

            # Count requests in last hour
            hour_requests = len(self.requests[client_id])

            return {
                "per_minute": self.requests_per_minute - minute_requests,
                "per_hour": self.requests_per_hour - hour_requests
            }


# Global rate limiter instance
rate_limiter = RateLimiter()


async def check_rate_limit(client_id: str) -> bool:
    """
    Check if client is within rate limits.

    Args:
        client_id: Unique identifier for client

    Returns:
        True if allowed, False if rate limited
    """
    return await rate_limiter.is_allowed(client_id)


async def get_rate_limit_status(client_id: str) -> Dict[str, int]:
    """
    Get current rate limit status for client.

    Args:
        client_id: Unique identifier for client

    Returns:
        Dictionary with remaining requests
    """
    return await rate_limiter.get_remaining_requests(client_id)