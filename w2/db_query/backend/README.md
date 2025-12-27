# Database Query Tool Backend

Backend API for Database Query Tool.

## Features

- Manage PostgreSQL database connections
- Execute SQL queries (SELECT only)
- Natural language to SQL conversion using OpenAI
- Query result export (CSV/JSON)
- Rate limiting for LLM endpoints

## Rate Limiting

The `/api/v1/dbs/{name}/query/natural` endpoint is rate limited to prevent abuse:

- **60 requests per minute** per client (based on IP address)
- **1000 requests per hour** per client

If the rate limit is exceeded, the API returns HTTP 429 with the following headers:
```
X-RateLimit-Limit: 60 requests per minute
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 60
```

## Configuration

Rate limiting can be configured via environment variables:

```bash
# Maximum requests per minute per client
RATE_LIMIT_REQUESTS_PER_MINUTE=60

# Maximum requests per hour per client
RATE_LIMIT_REQUESTS_PER_HOUR=1000
```

## Development

This is a Python project using FastAPI and SQLModel.

## License

MIT