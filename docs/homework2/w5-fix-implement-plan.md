# PostgreSQL MCP Server - 功能修复实施计划 (Implementation Plan)

## 文档信息

| 项目 | 内容 |
|------|------|
| 文档版本 | v1.1 |
| 创建日期 | 2026-02-12 |
| 关联 PRD | `docs/homework2/w5-fix-prd.md` |
| 关联 Spec | `docs/homework2/w5-fix-spec.md` |

---

## 1. 实施概览

本计划按照“先修行为偏差，再补测试验证”的顺序推进，确保每个阶段都可以独立回归。

---

## 2. 前置条件

- [ ] 进入目录：`cd w5/pg-mcp`
- [ ] 本地环境满足 Python `>=3.14`
- [ ] 可执行基础测试：`uv run pytest tests/unit/test_models.py`
- [ ] 已准备可用 `.env`（或测试专用环境变量）

---

## 3. 任务分解

### Phase 1：配置与模型修复（P0）

#### Task 1.1 扩展安全配置
- 文件：`w5/pg-mcp/src/pg_mcp/config/settings.py`
- 操作：
  1. `SecurityConfig` 增加 `blocked_tables`、`blocked_columns`、`allow_explain`
  2. 增加逗号分隔字符串解析
- 验证：
  - `uv run pytest tests/unit/test_config.py -k security -v`

#### Task 1.2 扩展弹性配置
- 文件：`w5/pg-mcp/src/pg_mcp/config/settings.py`
- 操作：
  1. `ResilienceConfig` 增加 `query_limit`、`llm_limit`
  2. 复用现有 `retry_delay`、`backoff_factor` 作为退避配置
- 验证：
  - `uv run pytest tests/unit/test_config.py -k resilience -v`

#### Task 1.3 修复 QueryResponse 重复 to_dict
- 文件：`w5/pg-mcp/src/pg_mcp/models/query.py`
- 操作：
  1. 删除重复 `to_dict`
  2. 保留统一行为：始终输出 `tokens_used`
- 验证：
  - `uv run pytest tests/unit/test_models.py -k tokens_used -v`

---

### Phase 2：多数据库与安全接线（P0）

#### Task 2.1 server 接入安全配置
- 文件：`w5/pg-mcp/src/pg_mcp/server.py`
- 操作：
  1. 初始化 `SQLValidator` 时改为读取 `_settings.security.*`
- 验证：
  - 增加/更新相关单元测试（validator 初始化参数）

#### Task 2.2 orchestrator 执行按库路由
- 文件：`w5/pg-mcp/src/pg_mcp/services/orchestrator.py`
- 操作：
  1. 将执行器改为 `dict[str, SQLExecutor]`
  2. `execute_query()` 按 `database_name` 选择 executor
- 验证：
  - `uv run pytest tests/unit/test_orchestrator.py -k database -v`

#### Task 2.3 server 注入 executor map
- 文件：`w5/pg-mcp/src/pg_mcp/server.py`
- 操作：
  1. 传入 `sql_executors` 而非单一 executor
- 验证：
  - `uv run pytest tests/integration/test_full_flow.py -k database -v`

---

### Phase 3：弹性与可观测性接入（P0）

#### Task 3.1 在 query() 接入 query limiter
- 文件：`w5/pg-mcp/src/pg_mcp/server.py`
- 操作：
  1. 使用 `async with _rate_limiter.for_queries(...)`
  2. 捕获限流超时并返回 `RATE_LIMITED`
- 验证：
  - `uv run pytest tests/e2e/test_mcp.py -k rate -v`

#### Task 3.2 在 LLM 调用接入 llm limiter
- 文件：`w5/pg-mcp/src/pg_mcp/services/orchestrator.py`
- 操作：
  1. SQL 生成与结果验证调用使用 `for_llm(...)`
- 验证：
  - `uv run pytest tests/unit/test_orchestrator.py -k llm -v`

#### Task 3.3 重试路径接入退避
- 文件：`w5/pg-mcp/src/pg_mcp/services/orchestrator.py`
- 操作：
  1. 使用 `retry_delay/backoff_factor` 计算 sleep 间隔
- 验证：
  - `uv run pytest tests/unit/test_orchestrator.py -k retry -v`

#### Task 3.4 指标打点接入
- 文件：
  - `w5/pg-mcp/src/pg_mcp/server.py`
  - `w5/pg-mcp/src/pg_mcp/services/orchestrator.py`
  - `w5/pg-mcp/src/pg_mcp/services/sql_validator.py`
  - `w5/pg-mcp/src/pg_mcp/services/sql_executor.py`
- 操作：
  1. 明确每层打点职责，避免重复计数
- 验证：
  - 新增/更新 `tests/unit/test_metrics.py`

---

### Phase 4：Token 统计落地（P0）

#### Task 4.1 SQLGenerator 提取 token
- 文件：`w5/pg-mcp/src/pg_mcp/services/sql_generator.py`
- 操作：
  1. 从 `response.usage.total_tokens` 取值
  2. 返回 `(sql, tokens_used)`

#### Task 4.2 ResultValidator 提取 token
- 文件：`w5/pg-mcp/src/pg_mcp/services/result_validator.py`
- 操作：
  1. 返回 `(validation_result, tokens_used)`

#### Task 4.3 orchestrator 汇总 token
- 文件：`w5/pg-mcp/src/pg_mcp/services/orchestrator.py`
- 操作：
  1. 累加生成与验证 token
  2. 写入 `QueryResponse.tokens_used`
- 验证：
  - `uv run pytest tests/integration/test_full_flow.py -k tokens -v`
  - `uv run pytest tests/e2e/test_mcp.py -k tokens -v`

---

### Phase 5：测试补充与文档同步（P0-P1）

#### Task 5.1 对齐现有 E2E 文件
- 文件：`w5/pg-mcp/tests/e2e/test_mcp.py`
- 操作：
  1. 强化限流、错误码、tokens 输出断言
  2. 移除无意义占位测试逻辑

#### Task 5.2 强化集成测试
- 文件：`w5/pg-mcp/tests/integration/test_full_flow.py`
- 操作：
  1. 增加多数据库路由与安全配置生效场景

#### Task 5.3 补齐缺失单测
- 新增文件：
  - `w5/pg-mcp/tests/unit/test_result_validator.py`
  - `w5/pg-mcp/tests/unit/test_metrics.py`
- 文件：`w5/pg-mcp/tests/unit/test_models.py`
- 操作：
  1. 补齐 token 提取与指标行为测试
  2. 增加 `to_dict` 行为回归测试

#### Task 5.4 更新配置文档
- 文件：`w5/pg-mcp/.env.example`
- 操作：
  1. 加入新增安全与弹性配置项说明

---

## 4. 验证检查清单

### 功能验证
- [ ] `database` 路由到正确 executor
- [ ] blocked table/column 与 EXPLAIN 策略按配置生效
- [ ] query/llm 限流触发时返回 `RATE_LIMITED`
- [ ] 重试包含退避等待
- [ ] `tokens_used` 在响应中稳定输出且值合理

### 质量验证
- [ ] `uv run pytest`
- [ ] `uv run pytest --cov=pg_mcp --cov-report=term-missing`
- [ ] `uv run ruff check src/ tests/`
- [ ] `uv run mypy src/pg_mcp/`

---

## 5. 推荐执行顺序

1. Phase 1（配置与模型）
2. Phase 2（多数据库与安全接线）
3. Phase 3（弹性与可观测性）
4. Phase 4（token 统计）
5. Phase 5（测试与文档）

---

## 6. 回滚策略

按 Phase 进行原子提交，便于回滚：

```bash
git commit -m "fix: phase1 settings and model consistency"
git commit -m "fix: phase2 multi-db routing and security wiring"
git commit -m "fix: phase3 resilience and observability integration"
git commit -m "fix: phase4 token extraction and aggregation"
git commit -m "test: phase5 coverage alignment and docs sync"
```

---

**文档状态**：✅ 已完成（与当前仓库结构对齐）
