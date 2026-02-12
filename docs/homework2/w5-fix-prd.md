# PostgreSQL MCP Server - 功能修复 PRD

## 文档信息

| 项目 | 内容 |
|------|------|
| 文档版本 | v1.1 |
| 创建日期 | 2026-02-12 |
| 作者 | Claude Code |
| 关联文档 | `docs/homework2/w5作业要求.txt`, `specs/w5/0006-pg-mcp-code-review.md`, `specs/w5/0008-pg-mcp-test-plan-review.md` |

---

## 1. 背景与问题陈述

### 1.1 背景

`w5/pg-mcp` 已具备核心模块能力（SQL 验证、熔断、限流、指标、结果验证等），但当前主要问题不是“模块不存在”，而是“主流程接线不完整”，导致作业要求中的缺失功能无法稳定生效。

### 1.2 问题拆解（基于当前代码）

#### 问题 1：多数据库能力未真正落地到执行路径
- `QueryOrchestrator` 可解析数据库名，但执行阶段仍使用单一 `sql_executor`
- 结果是“可解析、多库名”，但“执行未按库路由”

#### 问题 2：安全控制参数未从配置接入
- `SQLValidator` 支持 `blocked_tables`、`blocked_columns`、`allow_explain`
- 但 `server.py` 初始化时仍硬编码 `None` 与 `False`
- `SecurityConfig` 也未暴露对应字段

#### 问题 3：弹性与可观测性未完整接入请求主路径
- 限流器已创建，但 `query()` 未应用
- 生成 SQL 的重试循环存在，但未使用 `retry_delay/backoff_factor` 做退避
- MetricsCollector 已实现，但请求成功/失败、耗时、LLM token、SQL 拒绝、DB 执行耗时等关键指标未统一打点

#### 问题 4：响应模型与 token 统计仍有偏差
- `QueryResponse.to_dict()` 存在重复定义，行为被后者覆盖
- token 统计仅停留在模型字段，实际 OpenAI `usage` 未被完整提取并汇总

#### 问题 5：测试计划与仓库结构不一致，关键验证项缺失
- 文档中的测试路径与当前 `w5/pg-mcp/tests` 实际目录不对齐
- E2E/集成虽有文件，但关键断言与缺失功能对应关系不足

---

## 2. 目标与范围

### 2.1 修复目标

1. **多数据库执行路由生效**：请求解析到的数据库必须驱动对应 executor 执行
2. **安全配置可配置化**：`blocked_tables`、`blocked_columns`、`allow_explain` 从配置生效
3. **弹性能力接入主流程**：限流、重试退避在真实请求路径生效
4. **可观测性可用**：关键 Prometheus 指标在请求链路更新
5. **响应一致性修复**：去除重复 `to_dict`，稳定输出 `tokens_used`
6. **token 统计可追踪**：生成与结果验证的 token 可提取、可汇总
7. **测试与路径对齐**：基于现有 `tests/unit|integration|e2e` 结构补齐验证

### 2.2 范围界定

**包含**：
- `w5/pg-mcp/src/pg_mcp/config/settings.py`
- `w5/pg-mcp/src/pg_mcp/server.py`
- `w5/pg-mcp/src/pg_mcp/services/orchestrator.py`
- `w5/pg-mcp/src/pg_mcp/services/sql_generator.py`
- `w5/pg-mcp/src/pg_mcp/services/result_validator.py`
- `w5/pg-mcp/src/pg_mcp/services/sql_executor.py`
- `w5/pg-mcp/src/pg_mcp/services/sql_validator.py`
- `w5/pg-mcp/src/pg_mcp/models/query.py`
- `w5/pg-mcp/tests/`

**不包含**：
- 新数据库类型支持（如 MySQL）
- 与本次修复无关的大规模架构重写
- UI/前端能力

### 2.3 成功标准

1. ✅ 指定 `database` 时，实际执行命中对应数据库 executor
2. ✅ `.env` 可配置敏感表/列与 EXPLAIN 策略并生效
3. ✅ 超并发时返回 `RATE_LIMITED` 业务错误，并包含重试建议
4. ✅ 重试路径包含退避时间，且由配置控制
5. ✅ `/metrics` 可看到请求、LLM、SQL 拒绝、DB 执行等指标变化
6. ✅ `QueryResponse` 无重复 `to_dict`，`tokens_used` 输出稳定
7. ✅ 测试路径与仓库结构一致，关键修复点均有回归测试

---

## 3. 功能需求

### 3.1 多数据库执行路由修复

#### 需求描述
数据库名解析结果必须决定 SQL 实际执行器，避免“解析 A 库、执行 B 库”。

#### 验收标准
- [ ] `QueryOrchestrator` 按 `database_name` 选择 executor
- [ ] 多库场景下未指定数据库时返回明确错误
- [ ] 指定不存在数据库时返回明确错误

---

### 3.2 安全控制配置增强

#### 需求描述
安全策略应来自配置，不允许硬编码绕过。

#### 配置示例
```bash
SECURITY_BLOCKED_TABLES=users_sensitive,audit_logs
SECURITY_BLOCKED_COLUMNS=password_hash,ssn
SECURITY_ALLOW_EXPLAIN=false
```

#### 验收标准
- [ ] `SecurityConfig` 包含 `blocked_tables`、`blocked_columns`、`allow_explain`
- [ ] `server.py` 初始化 `SQLValidator` 时读取上述字段
- [ ] 访问被阻止对象时返回 `SECURITY_VIOLATION`

---

### 3.3 弹性能力接入（限流 + 重试退避）

#### 需求描述
在请求主链路应用 `MultiRateLimiter`，并在 SQL 生成重试中应用配置化退避。

#### 配置示例
```bash
RESILIENCE_QUERY_LIMIT=10
RESILIENCE_LLM_LIMIT=5
RESILIENCE_RETRY_DELAY=1.0
RESILIENCE_BACKOFF_FACTOR=2.0
```

#### 验收标准
- [ ] `query()` 使用 query limiter
- [ ] LLM 调用路径使用 llm limiter
- [ ] 重试间隔符合 `retry_delay/backoff_factor`
- [ ] 限流与重试行为有日志或指标可观测

---

### 3.4 可观测性接入

#### 需求描述
将已有指标模块接入请求关键路径，覆盖成功、失败、延迟、token、拒绝原因等。

#### 指标范围
- `pg_mcp_query_requests_total`
- `pg_mcp_query_duration_seconds`
- `pg_mcp_llm_calls_total`
- `pg_mcp_llm_latency_seconds`
- `pg_mcp_llm_tokens_used`
- `pg_mcp_sql_rejected_total`
- `pg_mcp_db_query_duration_seconds`

#### 验收标准
- [ ] 成功/失败请求计数正确递增
- [ ] 查询与 LLM 耗时可观测
- [ ] SQL 拒绝原因有统计

---

### 3.5 响应模型与 Token 统计修复

#### 需求描述
修复 `QueryResponse.to_dict` 冲突，并从 OpenAI 响应提取 token 用量。

#### 验收标准
- [ ] `QueryResponse` 仅保留一个 `to_dict`
- [ ] `tokens_used` 在响应中始终存在（无值时为 0）
- [ ] 生成 SQL + 结果验证 token 可汇总到响应

---

### 3.6 测试补充与对齐

#### 需求描述
在当前真实目录结构下补齐测试，不引入与仓库不一致的路径规划。

#### 当前目录基准
- `w5/pg-mcp/tests/unit/`
- `w5/pg-mcp/tests/integration/`
- `w5/pg-mcp/tests/e2e/`

#### P0 测试要求
- [ ] `tests/e2e/test_mcp.py`：限流、错误格式、tokens 输出、基础协议行为
- [ ] `tests/integration/test_full_flow.py`：多库路由、安全策略、指标/限流链路
- [ ] `tests/unit/test_models.py`：`to_dict` 行为与 `tokens_used` 输出
- [ ] `tests/unit/test_orchestrator.py`：executor 选择、退避重试、错误路径

#### P1 测试要求
- [ ] 新增 `tests/unit/test_result_validator.py`
- [ ] 新增 `tests/unit/test_metrics.py`

---

## 4. 非功能需求

### 4.1 性能
- 指标记录开销应可接受，不应显著影响请求时延
- 限流检查与重试退避实现需避免忙等

### 4.2 兼容性
- 向后兼容现有 `.env`
- 不破坏 `query(question, database, return_type)` MCP 工具接口
- 兼容当前项目 Python 要求（`>=3.14`）

### 4.3 可维护性
- 新增字段和行为需有对应单元测试
- 配置变更需同步 `.env.example`

---

## 5. 风险与依赖

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 多数据库改造引入回归 | 高 | 先补充单元测试再改主流程 |
| 指标重复打点导致数据失真 | 中 | 明确打点归属层级并写断言 |
| 退避配置过大导致延迟上升 | 中 | 设置上限并记录重试耗时 |
| E2E 依赖外部服务不稳定 | 中 | 优先使用 mock + 分层测试 |

---

## 6. 验收标准总结

### 功能验收
- [ ] 多数据库执行路由正确
- [ ] 安全配置从 `.env` 生效
- [ ] 限流与退避生效
- [ ] token 统计准确并返回
- [ ] 指标端点可观测

### 质量验收
- [ ] `uv run pytest` 通过
- [ ] `uv run pytest --cov=pg_mcp` 覆盖率 ≥ 80%
- [ ] `uv run ruff check src/ tests/` 通过
- [ ] `uv run mypy src/pg_mcp/` 通过

---

**文档状态**：✅ 已完成（与当前仓库结构对齐）
**下一步**：进入技术设计与实施计划落地
