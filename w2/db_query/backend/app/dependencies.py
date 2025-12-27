"""FastAPI dependencies for common functionality."""

from fastapi import Request, HTTPException, status
from typing import Optional
import logging

logger = logging.getLogger(__name__)


async def get_client_ip(request: Request) -> str:
    """
    Get client IP address from request.

    Args:
        request: FastAPI Request object

    Returns:
        Client IP address as string
    """
    # Try to get real IP from behind proxy
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        # x-forwarded-for can contain multiple IPs, first is the client
        ip = forwarded.split(",")[0].strip()
        if ip:
            return ip

    # Try X-Real-IP header
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()

    # Fall back to client host
    client_host = request.client.host if request.client else "unknown"
    return client_host


async def get_rate_limiter_client(request: Request) -> str:
    """
    Get unique client identifier for rate limiting.

    Args:
        request: FastAPI Request object

    Returns:
        Unique client identifier
    """
    # For now, use IP address. Could be extended to use API keys in the future.
    ip = await get_client_ip(request)

    # Add a simple prefix to indicate this is an IP-based rate limit
    return f"ip_{ip}"


async def rate_limit_dependency(request: Request):
    """
    Dependency to check rate limits before processing request.

    Args:
        request: FastAPI Request object

    Raises:
        HTTPException: If client is rate limited
    """
    from app.services.rate_limiter import check_rate_limit

    client_id = await get_rate_limiter_client(request)
    is_allowed = await check_rate_limit(client_id)

    if not is_allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Please try again later.",
            headers={
                "X-RateLimit-Limit": "60 requests per minute",
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": "60",
            }
        )