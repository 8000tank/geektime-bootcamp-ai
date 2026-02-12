#!/usr/bin/env bash
set -uo pipefail

# Compare the same business question via:
# 1) direct SQL (psql)
# 2) pg-mcp query() tool path
#
# Usage:
#   ./scripts/compare_direct_vs_mcp.sh
#   DB_NAME=blog_small DB_USER=postgres PGPASSWORD=postgres ./scripts/compare_direct_vs_mcp.sh
#   QUESTION="查询博客中最活跃的作者" ./scripts/compare_direct_vs_mcp.sh

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-blog_small}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-${PGPASSWORD:-}}"

# LLM provider compatibility (OpenAI-compatible endpoints like DeepSeek)
OPENAI_BASE_URL="${OPENAI_BASE_URL:-${DEEPSEEK_BASE_URL:-}}"
OPENAI_MODEL="${OPENAI_MODEL:-${DEEPSEEK_MODEL:-}}"
OPENAI_API_KEY="${OPENAI_API_KEY:-${DEEPSEEK_API_KEY:-}}"

QUESTION="${QUESTION:-查询博客中最活跃的作者}"
RETURN_TYPE="${RETURN_TYPE:-result}"

DIRECT_SQL="${DIRECT_SQL:-SELECT
    username,
    full_name,
    role,
    post_count,
    comment_count,
    last_post_date
FROM user_stats
WHERE role IN ('admin', 'author')
ORDER BY post_count DESC, comment_count DESC
LIMIT 10;}"

echo "===================================="
echo "对比开始：direct SQL vs pg-mcp"
echo "数据库: ${DB_NAME}"
echo "问题: ${QUESTION}"
echo "===================================="
echo

echo "[1/2] direct SQL (psql)"
echo "SQL:"
echo "${DIRECT_SQL}"
echo
if command -v psql >/dev/null 2>&1; then
  if ! psql \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -c "${DIRECT_SQL}"; then
    echo "direct SQL 执行失败（请检查 DB_* 和 PGPASSWORD 配置）。"
  fi
else
  echo "psql 未安装，跳过 direct SQL 执行。"
fi
echo

echo "[2/2] pg-mcp query()"
echo "return_type: ${RETURN_TYPE}"
if [[ -n "${OPENAI_BASE_URL}" ]]; then
  echo "openai_base_url: ${OPENAI_BASE_URL}"
fi
if [[ -n "${OPENAI_MODEL}" ]]; then
  echo "openai_model: ${OPENAI_MODEL}"
fi
echo
if ! COMPARE_DB_NAME="${DB_NAME}" \
COMPARE_QUESTION="${QUESTION}" \
COMPARE_RETURN_TYPE="${RETURN_TYPE}" \
DATABASE_HOST="${DB_HOST}" \
DATABASE_PORT="${DB_PORT}" \
DATABASE_NAME="${DB_NAME}" \
DATABASE_USER="${DB_USER}" \
DATABASE_PASSWORD="${DB_PASSWORD}" \
OPENAI_API_KEY="${OPENAI_API_KEY}" \
OPENAI_BASE_URL="${OPENAI_BASE_URL}" \
OPENAI_MODEL="${OPENAI_MODEL}" \
uv run python - <<'PY'
import asyncio
import json
import os

from pg_mcp.server import lifespan, mcp, query


async def _main() -> None:
    db_name = os.getenv("COMPARE_DB_NAME")
    question = os.getenv("COMPARE_QUESTION", "")
    return_type = os.getenv("COMPARE_RETURN_TYPE", "result")

    try:
        async with lifespan(mcp):
            result = await query(
                question=question,
                database=db_name,
                return_type=return_type,
            )
    except Exception as exc:  # pragma: no cover
        result = {
            "success": False,
            "error": {
                "code": "SCRIPT_RUNTIME_ERROR",
                "message": str(exc),
            },
            "tokens_used": 0,
        }

    print(json.dumps(result, ensure_ascii=False, indent=2))


asyncio.run(_main())
PY
then
  echo "pg-mcp 执行失败（请检查 OPENAI_API_KEY、数据库配置与依赖环境）。"
fi

echo
echo "===================================="
echo "对比结束"
echo "提示：若要复现截图场景，优先设置 DB_* 与 OPENAI_API_KEY。"
echo "===================================="
