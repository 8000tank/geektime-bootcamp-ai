# 数据导出功能说明文档

## 功能概述

为数据库查询工具添加了数据导出功能，支持将查询结果导出为 CSV 和 JSON 格式。用户可以在执行查询后导出结果，或者一键执行查询并导出。

## 技术实现

### 后端实现

#### 1. 导出服务模块 (`app/services/export_service.py`)

**ExportService 类**提供三个核心方法：

- `export_to_csv(result: QueryResult) -> Iterator[bytes]`
  - 将查询结果导出为 CSV 格式
  - 使用 UTF-8 with BOM 编码，确保 Excel 正确打开
  - 支持流式生成，避免大数据集内存溢出
  - 空结果返回 0 字节文件

- `export_to_json(result: QueryResult) -> str`
  - 将查询结果导出为 JSON 格式
  - 包含元数据：columns, rows, rowCount, executionTimeMs, exportedAt
  - 空结果返回空字符串（0 字节）

- `generate_filename(database_name: str, format: str) -> str`
  - 生成带时间戳的文件名
  - 格式：`{database_name}_query_{YYYYMMDD_HHMMSS}.{format}`

#### 2. 数据模型扩展 (`app/models/schemas.py`)

新增 `ExportSnapshotRequest` 模型：

```python
class ExportSnapshotRequest(BaseModel):
    format: Literal["csv", "json"]  # 导出格式
    sql: str                         # 已执行的 SQL
    result: QueryResult              # 当前页面查询结果快照
```

#### 3. API 端点 (`app/api/v1/queries.py`)

**POST `/api/v1/dbs/{name}/export/snapshot`**

- 导出基于当前页面已展示的查询结果快照，不重新执行 SQL
- 验证数据库连接是否存在
- 记录导出历史到 QueryHistory 表
- 返回流式响应，支持大数据集导出

**请求示例**：
```json
{
  "format": "csv",
  "sql": "SELECT * FROM users LIMIT 1000",
  "result": {
    "columns": [{"name": "id", "dataType": "integer"}],
    "rows": [{"id": 1}],
    "rowCount": 1,
    "executionTimeMs": 120,
    "sql": "SELECT * FROM users LIMIT 1000"
  }
}
```

**响应**：
- Content-Type: `text/csv` 或 `application/json`
- Content-Disposition: `attachment; filename="dbname_query_20240115_103000.csv"`
- Body: 文件内容流

### 前端实现

#### 1. API 客户端扩展 (`src/services/api.ts`)

新增两个函数：

- `exportQuerySnapshot(databaseName, result, format)`
  - 调用后端导出 API
  - 返回 Blob 响应

- `downloadBlobFromResponse(response)`
  - 从响应头解析文件名
  - 触发浏览器下载

#### 2. ExportButton 组件 (`src/components/ExportButton.tsx`)

**功能**：
- 导出当前页面已展示的查询结果
- 下拉菜单选择 CSV 或 JSON 格式
- 显示加载状态和成功/失败提示

**Props**：
- `databaseName`: 数据库名称
- `result`: 当前查询结果（QueryResult | null）
- `disabled`: 是否禁用

#### 3. ExecuteAndExportButton 组件 (`src/components/ExecuteAndExportButton.tsx`)

**功能**：
- 一键执行查询并导出结果
- 先执行查询并在页面展示结果
- 再导出同一份结果快照
- 确保页面展示内容与导出内容一致

**Props**：
- `databaseName`: 数据库名称
- `sql`: SQL 查询语句
- `disabled`: 是否禁用
- `onResult`: 查询结果回调（用于更新页面）
- `onSuccess`: 成功回调（用于刷新历史记录）

#### 4. 页面集成 (`src/pages/queries/execute.tsx`)

在查询执行页面的操作栏中添加了两个导出按钮：

```
[Execute] [Export ▼] [Execute & Export ▼] [Refresh History]
```

- **Export**: 导出当前已展示的查询结果
- **Execute & Export**: 执行查询并自动导出

## 数据格式规范

### CSV 格式

- 第一行为列名
- 使用逗号分隔
- 字段包含特殊字符时使用双引号包裹
- NULL 值表示为空字符串
- 编码：UTF-8 with BOM（兼容 Excel）
- 空结果：0 字节文件

**示例**：
```csv
id,name,email,created_at
1,John Doe,john@example.com,2024-01-01 10:00:00
2,"Smith, Jane",jane@example.com,2024-01-02 11:30:00
```

### JSON 格式

- 包含 columns、rows、rowCount、executionTimeMs、exportedAt
- 使用标准 JSON 格式，缩进 2 空格
- 空结果：空字符串（0 字节）

**示例**：
```json
{
  "columns": ["id", "name", "email"],
  "rows": [
    {"id": 1, "name": "John Doe", "email": "john@example.com"}
  ],
  "rowCount": 1,
  "executionTimeMs": 120,
  "exportedAt": "2024-01-15T10:30:00Z"
}
```

## 使用方法

### 方式一：导出当前结果

1. 在 SQL 编辑器中输入查询
2. 点击 **Execute** 按钮执行查询
3. 查看查询结果
4. 点击 **Export** 下拉菜单
5. 选择 **导出为 CSV** 或 **导出为 JSON**
6. 浏览器自动下载文件

### 方式二：一键执行并导出

1. 在 SQL 编辑器中输入查询
2. 点击 **Execute & Export** 下拉菜单
3. 选择 **执行并导出为 CSV** 或 **执行并导出为 JSON**
4. 系统自动执行查询、展示结果并下载文件

## 特性说明

### 1. 基于快照导出

- 导出功能基于当前页面已展示的查询结果快照
- 不会重新执行 SQL 查询
- 确保导出内容与页面展示内容完全一致
- 避免因数据变化导致的不一致问题

### 2. 空结果处理

- 当查询结果为空（rowCount = 0）时
- CSV 和 JSON 格式都返回 0 字节文件
- 符合 HTTP 200 响应规范
- 文件名仍然包含时间戳

### 3. 导出历史记录

- 每次导出操作都会记录到查询历史
- 查询来源标记为 `EXPORT`
- 可在历史记录中查看导出操作

### 4. 错误处理

- 数据库连接不存在：返回 404
- 请求参数错误：返回 400
- 服务器内部错误：返回 500
- 前端显示友好的错误提示

## 性能优化

1. **流式响应**：使用 `StreamingResponse` 避免大数据集一次性加载到内存
2. **前端优化**：使用 Blob API 处理大文件下载
3. **快照导出**：不重新执行 SQL，直接导出当前结果集

## 安全考虑

1. **权限验证**：验证数据库连接是否存在
2. **SQL 注入防护**：复用现有的 SQL 验证逻辑
3. **审计日志**：记录所有导出操作到查询历史

## 已知限制

1. 单次导出建议不超过 100,000 行数据
2. 导出操作超时时间为 30 秒
3. 仅支持 CSV 和 JSON 格式（未来可扩展 Excel、SQL 等）

## 未来扩展

- [ ] 支持 Excel (.xlsx) 格式导出
- [ ] 支持 SQL 文件导出（包含 INSERT 语句）
- [ ] 支持自定义导出字段
- [ ] 支持导出模板保存
- [ ] 支持定时导出任务
- [ ] 智能导出提示（查询成功后自动询问是否导出）
- [ ] 快捷键支持（Ctrl+E 快速导出）

## 测试建议

### 后端测试

1. **单元测试**：
   - 测试 CSV 导出（正常数据、特殊字符、NULL 值、空结果）
   - 测试 JSON 导出（数据格式、元数据完整性、空结果）
   - 测试文件名生成

2. **集成测试**：
   - 测试完整导出流程
   - 测试错误场景（数据库不存在、快照结构错误）
   - 测试大数据集导出性能

### 前端测试

1. **组件测试**：
   - 测试 ExportButton 渲染和点击事件
   - 测试 ExecuteAndExportButton 执行并导出流程
   - 测试禁用状态和加载状态

2. **端到端测试**：
   - 测试完整用户流程（执行查询 → 导出）
   - 测试一键执行并导出流程
   - 验证下载的文件内容正确

## 技术栈

- **后端**：Python 3.12, FastAPI, SQLModel
- **前端**：React 18, TypeScript, Ant Design, Axios
- **数据库**：PostgreSQL / MySQL（查询目标）, SQLite（元数据存储）

## 文件清单

### 后端文件
- `backend/app/services/export_service.py` - 导出服务模块
- `backend/app/models/schemas.py` - 数据模型（新增 ExportSnapshotRequest）
- `backend/app/api/v1/queries.py` - API 路由（新增 export/snapshot 端点）

### 前端文件
- `frontend/src/services/api.ts` - API 客户端（新增导出函数）
- `frontend/src/components/ExportButton.tsx` - 导出按钮组件
- `frontend/src/components/ExecuteAndExportButton.tsx` - 执行并导出按钮组件
- `frontend/src/pages/queries/execute.tsx` - 查询页面（集成导出按钮）

## 开发者

- 实现日期：2024-01-15
- 开发工具：Claude Code (Opus 4.6)
- 参考文档：
  - PRD: `docs/homework/w2-export-feature-prd.md`
  - 技术设计：`docs/homework/w2-export-feature-spec.md`
  - 开发计划：`docs/homework/w2-export-feature-plan.md`

## 总结

数据导出功能已成功实现，支持 CSV 和 JSON 两种格式，提供了两种导出方式（导出当前结果、一键执行并导出），满足了作业要求的所有核心功能。代码结构清晰，易于维护和扩展。
