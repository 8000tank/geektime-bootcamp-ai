# PostgreSQL MCP Server - 功能修复技术设计文档 (Spec)

## 文档信息

| 项目 | 内容 |
|------|------|
| 文档版本 | v1.1 |
| 创建日期 | 2026-02-12 |
| 关联 PRD | `docs/homework2/w5-fix-prd.md` |

---

## 1. 概述

本设计聚焦“模块已存在但主流程接线不完整”的修复，确保作业要求中的三类问题真正落地：
1. 多数据库与安全控制
2. 弹性与可观测性
3. 响应/模型缺陷与测试覆盖

---

## 2. 修复项 A：多数据库执行路由

### 2.1 当前问题
- `QueryOrchestrator` 虽可 `_resolve_database`，但执行调用仍固定 `self.sql_executor.execute(...)`
- 实际执行未按数据库切换

### 2.2 设计方案

#### 变更文件
- `w5/pg-mcp/src/pg_mcp/services/orchestrator.py`
- `w5/pg-mcp/src/pg_mcp/server.py`

#### 关键改动
1. `QueryOrchestrator` 从“单 executor”调整为“按库名选择 executor”
2. 在 `execute_query()` 中基于 `database_name` 取对应 executor 再执行
3. `server.py` 初始化 orchestrator 时注入全量 `sql_executors`

#### 伪代码
```python
# orchestrator.py
executor = self.sql_executors.get(database_name)
if executor is None:
    raise DatabaseError(...)
results, total_count = await executor.execute(generated_sql)
```

---

## 3. 修复项 B：安全配置接入

### 3.1 当前问题
- `SQLValidator` 已支持 `blocked_tables/blocked_columns/allow_explain`
- `server.py` 初始化时仍硬编码 `None/False`

### 3.2 设计方案

#### 变更文件
- `w5/pg-mcp/src/pg_mcp/config/settings.py`
- `w5/pg-mcp/src/pg_mcp/server.py`

#### 关键改动
1. 扩展 `SecurityConfig`
2. 支持环境变量字符串到列表的解析
3. 初始化 `SQLValidator` 时读取 `_settings.security` 对应字段

#### 配置模型示例
```python
class SecurityConfig(BaseSettings):
    blocked_tables: list[str] = Field(default_factory=list)
    blocked_columns: list[str] = Field(default_factory=list)
    allow_explain: bool = False
```

---

## 4. 修复项 C：弹性接入（限流 + 重试退避）

### 4.1 当前问题
- 限流器已创建但未在请求链路使用
- 生成 SQL 的重试未使用 `retry_delay/backoff_factor`

### 4.2 设计方案

#### 变更文件
- `w5/pg-mcp/src/pg_mcp/config/settings.py`
- `w5/pg-mcp/src/pg_mcp/server.py`
- `w5/pg-mcp/src/pg_mcp/services/orchestrator.py`

#### 配置扩展
```python
class ResilienceConfig(BaseSettings):
    query_limit: int = 10
    llm_limit: int = 5
    retry_delay: float = 1.0
    backoff_factor: float = 2.0
```

#### 限流接入策略
1. `query()` 入口使用 `async with _rate_limiter.for_queries(timeout=...)`
2. 生成 SQL 与结果验证调用使用 `async with limiter.for_llm(timeout=...)`
3. 捕获限流超时，返回统一 `RATE_LIMITED` 错误结构

> 注意：不使用 `allow_query()`，因为当前实现提供的是上下文管理器 API。

#### 退避策略
在 `_generate_sql_with_retry` 的失败重试分支增加：
```python
delay = retry_delay * (backoff_factor ** attempt)
await asyncio.sleep(delay)
```

---

## 5. 修复项 D：可观测性接入

### 5.1 当前问题
指标定义存在，但请求链路打点不完整。

### 5.2 设计方案

#### 变更文件
- `w5/pg-mcp/src/pg_mcp/server.py`
- `w5/pg-mcp/src/pg_mcp/services/orchestrator.py`
- `w5/pg-mcp/src/pg_mcp/services/sql_executor.py`
- `w5/pg-mcp/src/pg_mcp/services/sql_validator.py`

#### 打点归属（避免重复）
1. `server.py`：请求总时长、请求总状态（入口/出口）
2. `orchestrator.py`：LLM 调用次数/耗时/token
3. `sql_validator.py`：SQL 拒绝原因
4. `sql_executor.py`：DB 执行耗时

---

## 6. 修复项 E：响应模型与 Token 统计

### 6.1 当前问题
- `QueryResponse.to_dict` 重复定义导致行为冲突
- token 字段有模型无数据

### 6.2 设计方案

#### 变更文件
- `w5/pg-mcp/src/pg_mcp/models/query.py`
- `w5/pg-mcp/src/pg_mcp/services/sql_generator.py`
- `w5/pg-mcp/src/pg_mcp/services/result_validator.py`
- `w5/pg-mcp/src/pg_mcp/services/orchestrator.py`

#### 关键改动
1. `QueryResponse` 仅保留一个 `to_dict`
2. `SQLGenerator.generate()` 返回 `(sql, tokens_used)`
3. `ResultValidator.validate()` 返回 `(validation_result, tokens_used)`
4. orchestrator 汇总 token 并写入 `QueryResponse.tokens_used`

---

## 7. 测试设计（与当前目录对齐）

### 7.1 目标文件
- `w5/pg-mcp/tests/e2e/test_mcp.py`
- `w5/pg-mcp/tests/integration/test_full_flow.py`
- `w5/pg-mcp/tests/unit/test_orchestrator.py`
- `w5/pg-mcp/tests/unit/test_models.py`
- `w5/pg-mcp/tests/unit/test_resilience.py`
- 新增：`w5/pg-mcp/tests/unit/test_result_validator.py`
- 新增：`w5/pg-mcp/tests/unit/test_metrics.py`

### 7.2 P0 用例
1. 多数据库：指定库名命中正确 executor
2. 安全配置：blocked table/column、allow_explain 生效
3. 限流：并发超限返回 `RATE_LIMITED`
4. token：响应包含并正确累加
5. 模型：`QueryResponse.to_dict` 行为唯一且稳定

### 7.3 P1 用例
1. 退避重试时序验证
2. metrics 打点调用验证
3. result validator token 提取异常分支

---

## 8. 向后兼容性

| 变更 | 兼容性说明 |
|------|------------|
| `SecurityConfig` 新字段 | 默认值安全、对旧 `.env` 兼容 |
| `ResilienceConfig` 新字段 | 有默认值，不破坏旧配置 |
| 服务层方法签名调整 | 仅内部调用方，需同步更新 orchestrator/server |
| `QueryResponse.to_dict` 修复 | 对外返回结构更稳定，不减少字段 |

---

## 9. 实施顺序

1. `settings.py`：补齐安全与弹性配置字段
2. `models/query.py`：修复重复 `to_dict`
3. `server.py`：接入安全配置、query limiter、executor map 注入
4. `orchestrator.py`：多库路由、llm limiter、退避重试、token 汇总
5. `sql_generator.py` / `result_validator.py`：token 提取
6. `sql_validator.py` / `sql_executor.py`：补齐指标打点
7. `tests/`：按 P0→P1 补齐

---

**文档状态**：✅ 已完成（与当前仓库结构对齐）
