# 数据导出功能设计文档（Technical Spec）

## 1. 架构设计

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                         Frontend                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ QueryExecute │  │ ResultTable  │  │ ExportButton │      │
│  │    Page      │──│  Component   │──│  Component   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                                     │              │
│         └─────────────────┬───────────────────┘              │
│                           │                                  │
│                    ┌──────▼──────┐                          │
│                    │  API Client │                          │
│                    └──────┬──────┘                          │
└───────────────────────────┼─────────────────────────────────┘
                            │ HTTP
┌───────────────────────────▼─────────────────────────────────┐
│                         Backend                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Queries    │  │   Export     │  │   Database   │      │
│  │   Router     │──│   Service    │──│   Adapter    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                                 │
│         │           ┌──────▼──────┐                         │
│         │           │  Formatters │                         │
│         │           │ CSV / JSON  │                         │
│         │           └─────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 数据流

```
用户操作 → 前端组件 → API 请求 → 后端路由 → 导出服务 → 格式化器 → 流式响应 → 浏览器下载
```

## 2. 后端设计

### 2.1 API 接口设计

#### 2.1.1 导出查询结果

**端点**: `POST /api/v1/dbs/{name}/export/snapshot`

**请求参数**:
```json
{
  "format": "csv",
  "sql": "SELECT * FROM users LIMIT 1000",
  "result": {
    "columns": [{"name": "id", "dataType": "integer"}],
    "rows": [{"id": 1}],
    "rowCount": 1,
    "executionTimeMs": 120
  }
}
```

说明：
- 导出基于当前页面已展示的查询结果快照，不重新执行 SQL
- 当 `result.rowCount = 0` 时返回 200，响应体为 **0 字节**

**响应**:
- Content-Type: `text/csv` 或 `application/json`
- Content-Disposition: `attachment; filename="dbname_query_20240115_103000.csv"`
- Body: 文件内容流

**错误响应**:
```json
{
  "detail": "Invalid snapshot payload"
}
```

**状态码**:
- 200: 导出成功
- 400: 请求参数错误（如格式不支持、快照结构不合法）
- 404: 数据库连接不存在
- 500: 服务器内部错误

#### 2.1.2 一键执行并导出（F2）

前端流程：
1. 调用 `POST /api/v1/dbs/{name}/query` 执行 SQL，拿到 `QueryResult`
2. 先将 `QueryResult` 渲染到结果表格
3. 再调用 `POST /api/v1/dbs/{name}/export/snapshot` 导出同一份快照

这样可保证“页面展示内容”和“导出内容”一致，并满足“查询结果同时显示在界面上”。

### 2.2 数据模型

#### 2.2.1 ExportSnapshotRequest

```python
# app/models/schemas.py

from typing import Literal
from pydantic import BaseModel, Field

class ExportSnapshotRequest(BaseModel):
    """导出快照请求模型"""
    format: Literal["csv", "json"] = Field(..., description="导出格式")
    sql: str = Field(..., description="已执行并展示的 SQL")
    result: QueryResult = Field(..., description="当前页面查询结果快照")

    class Config:
        json_schema_extra = {
            "example": {
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
        }
```

### 2.3 导出服务

#### 2.3.1 ExportService 类设计

```python
# app/services/export_service.py

from typing import Iterator
from io import StringIO
import csv
import json
from datetime import datetime
from app.models.schemas import QueryResult

class ExportService:
    """数据导出服务"""

    @staticmethod
    def export_to_csv(result: QueryResult) -> Iterator[bytes]:
        """
        将查询结果导出为 CSV 格式

        Args:
            result: 查询结果对象

        Yields:
            CSV 内容的字符串块
        """
        if result.row_count == 0:
            # PRD 约定：空结果返回 0 字节文件
            yield b""
            return

        # 非空结果使用 UTF-8 with BOM，保证 Excel 打开兼容
        output = StringIO()
        writer = csv.writer(output, quoting=csv.QUOTE_MINIMAL)

        # 写入表头
        headers = [col.name for col in result.columns]
        writer.writerow(headers)
        yield ("\ufeff" + output.getvalue()).encode("utf-8")
        output.truncate(0)
        output.seek(0)

        # 写入数据行
        for row in result.rows:
            values = [row.get(col.name) for col in result.columns]
            # 处理 None 值
            values = ['' if v is None else str(v) for v in values]
            writer.writerow(values)
            yield output.getvalue().encode("utf-8")
            output.truncate(0)
            output.seek(0)

    @staticmethod
    def export_to_json(result: QueryResult) -> str:
        """
        将查询结果导出为 JSON 格式

        Args:
            result: 查询结果对象

        Returns:
            JSON 字符串
        """
        if result.row_count == 0:
            # PRD 约定：空结果返回 0 字节文件
            return ""

        export_data = {
            "columns": [col.name for col in result.columns],
            "rows": result.rows,
            "rowCount": result.row_count,
            "executionTimeMs": result.execution_time_ms,
            "exportedAt": datetime.utcnow().isoformat() + "Z"
        }
        return json.dumps(export_data, indent=2, ensure_ascii=False)

    @staticmethod
    def generate_filename(database_name: str, format: str) -> str:
        """
        生成导出文件名

        Args:
            database_name: 数据库名称
            format: 文件格式

        Returns:
            文件名字符串
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{database_name}_query_{timestamp}.{format}"
```

### 2.4 路由实现

```python
# app/api/v1/queries.py

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlmodel import Session, select
from app.database import get_session
from app.models.database import DatabaseConnection
from app.models.schemas import ExportSnapshotRequest
from app.services.export_service import ExportService

router = APIRouter(prefix="/api/v1/dbs", tags=["queries"])

@router.post("/{name}/export/snapshot")
async def export_snapshot(
    name: str,
    export_request: ExportSnapshotRequest,
    session: Session = Depends(get_session),
):
    """
    导出查询结果为指定格式

    Args:
        name: 数据库连接名称
        export_request: 导出请求（包含结果快照和格式）
        session: 数据库会话

    Returns:
        StreamingResponse: 文件下载响应
    """
    # 获取数据库连接
    statement = select(DatabaseConnection).where(DatabaseConnection.name == name)
    connection = session.exec(statement).first()

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Database connection '{name}' not found",
        )

    result = export_request.result

    # 生成文件名
    filename = ExportService.generate_filename(name, export_request.format)

    # 根据格式导出
    if export_request.format == "csv":
        content = ExportService.export_to_csv(result)
        media_type = "text/csv"
    else:  # json
        content = ExportService.export_to_json(result)
        media_type = "application/json"

    # 返回流式响应
    return StreamingResponse(
        iter([content.encode("utf-8")]) if isinstance(content, str) else content,
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )
```

错误码映射：
- `SqlValidationError`（来自 `/query`）→ 400
- 数据库连接不存在 → 404
- 导出序列化失败 → 500

### 2.5 QuerySource 枚举扩展

```python
# app/models/query.py

from enum import Enum

class QuerySource(str, Enum):
    """查询来源"""
    MANUAL = "manual"           # 手动执行
    NATURAL_LANGUAGE = "natural_language"  # 自然语言转换
    EXPORT = "export"           # 导出操作
```

## 3. 前端设计

### 3.1 组件设计

#### 3.1.1 ExportButton 组件

```typescript
// src/components/ExportButton.tsx

import React, { useState } from "react";
import { Button, Dropdown, message } from "antd";
import { DownloadOutlined } from "@ant-design/icons";
import type { MenuProps } from "antd";
import { QueryResult } from "../types/query";
import { exportQuerySnapshot, downloadBlobFromResponse } from "../services/api";

interface ExportButtonProps {
  databaseName: string;
  result: QueryResult | null;
  disabled?: boolean;
}

export const ExportButton: React.FC<ExportButtonProps> = ({
  databaseName,
  result,
  disabled = false,
}) => {
  const [loading, setLoading] = useState(false);

  const handleExport = async (format: "csv" | "json") => {
    if (!result) {
      message.warning("请先执行查询");
      return;
    }

    setLoading(true);
    try {
      const response = await exportQuerySnapshot(databaseName, result, format);
      downloadBlobFromResponse(response);

      message.success(`导出 ${format.toUpperCase()} 成功`);
    } catch (error: any) {
      message.error(`导出失败: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const menuItems: MenuProps["items"] = [
    {
      key: "csv",
      label: "导出为 CSV",
      onClick: () => handleExport("csv"),
    },
    {
      key: "json",
      label: "导出为 JSON",
      onClick: () => handleExport("json"),
    },
  ];

  return (
    <Dropdown menu={{ items: menuItems }} disabled={disabled || !result}>
      <Button
        icon={<DownloadOutlined />}
        loading={loading}
        disabled={disabled || !result}
      >
        导出
      </Button>
    </Dropdown>
  );
};
```

#### 3.1.2 ExecuteAndExportButton 组件

```typescript
// src/components/ExecuteAndExportButton.tsx

import React, { useState } from "react";
import { Button, Dropdown, message } from "antd";
import { ThunderboltOutlined } from "@ant-design/icons";
import type { MenuProps } from "antd";
import { QueryResult } from "../types/query";
import { executeQuery, exportQuerySnapshot, downloadBlobFromResponse } from "../services/api";

interface ExecuteAndExportButtonProps {
  databaseName: string;
  sql: string;
  disabled?: boolean;
  onResult?: (result: QueryResult) => void;
  onSuccess?: () => void;
}

export const ExecuteAndExportButton: React.FC<ExecuteAndExportButtonProps> = ({
  databaseName,
  sql,
  disabled = false,
  onResult,
  onSuccess,
}) => {
  const [loading, setLoading] = useState(false);

  const handleExecuteAndExport = async (format: "csv" | "json") => {
    if (!sql.trim()) {
      message.warning("请输入 SQL 查询");
      return;
    }

    setLoading(true);
    try {
      // 1) 先执行查询并在页面展示结果
      const queryResult = await executeQuery(databaseName, sql.trim());
      onResult?.(queryResult);

      // 2) 再导出同一份结果快照
      const response = await exportQuerySnapshot(databaseName, queryResult, format);
      downloadBlobFromResponse(response);

      message.success(`执行并导出 ${format.toUpperCase()} 成功`);
      onSuccess?.();
    } catch (error: any) {
      message.error(`执行失败: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const menuItems: MenuProps["items"] = [
    {
      key: "csv",
      label: "执行并导出为 CSV",
      onClick: () => handleExecuteAndExport("csv"),
    },
    {
      key: "json",
      label: "执行并导出为 JSON",
      onClick: () => handleExecuteAndExport("json"),
    },
  ];

  return (
    <Dropdown menu={{ items: menuItems }} disabled={disabled}>
      <Button
        type="primary"
        icon={<ThunderboltOutlined />}
        loading={loading}
        disabled={disabled}
      >
        执行并导出
      </Button>
    </Dropdown>
  );
};
```

### 3.2 API 客户端

```typescript
// src/services/api.ts

import axios from "axios";
import type { AxiosResponse } from "axios";
import { QueryResult } from "../types/query";

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "http://localhost:8000",
  timeout: 30000,
});

export const executeQuery = async (
  databaseName: string,
  sql: string
): Promise<QueryResult> => {
  const response = await apiClient.post<QueryResult>(
    `/api/v1/dbs/${databaseName}/query`,
    { sql }
  );
  return response.data;
};

export const exportQuerySnapshot = async (
  databaseName: string,
  result: QueryResult,
  format: "csv" | "json"
): Promise<AxiosResponse<Blob>> => {
  return apiClient.post(
    `/api/v1/dbs/${databaseName}/export/snapshot`,
    { format, sql: result.sql, result },
    { responseType: "blob" }
  );
};

export const downloadBlobFromResponse = (response: AxiosResponse<Blob>) => {
  const disposition = response.headers["content-disposition"] || "";
  const matched = disposition.match(/filename="?([^"]+)"?/);
  const filename = matched?.[1] || "export.dat";

  const url = URL.createObjectURL(response.data);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
};
```

### 3.3 页面集成

```typescript
// src/pages/queries/execute.tsx (修改部分)

import { ExportButton } from "../../components/ExportButton";
import { ExecuteAndExportButton } from "../../components/ExecuteAndExportButton";

// 在 Card 的 extra 部分添加按钮
<Card
  title={`Execute Query - ${databaseName}`}
  extra={
    <Space>
      <Button
        type="primary"
        icon={<PlayCircleOutlined />}
        onClick={handleExecute}
        loading={loading}
      >
        执行
      </Button>
      <ExecuteAndExportButton
        databaseName={databaseName!}
        sql={sql}
        disabled={loading}
        onResult={setResult}
        onSuccess={loadHistory}
      />
      <ExportButton
        databaseName={databaseName!}
        result={result}
        disabled={loading}
      />
      <Button
        icon={<ReloadOutlined />}
        onClick={loadHistory}
        loading={loadingHistory}
      >
        刷新历史
      </Button>
    </Space>
  }
>
```

### 3.4 智能提示功能（可选）

```typescript
// src/pages/queries/execute.tsx

import { Modal, Button, Space } from "antd";

const [exportPromptOpen, setExportPromptOpen] = useState(false);
const [lastResult, setLastResult] = useState<QueryResult | null>(null);

const handleExecute = async () => {
  // ... 执行查询逻辑 ...

  // 查询成功后提示导出
  if (response.data.rowCount > 0) {
    setLastResult(response.data);
    setExportPromptOpen(true);
  }
};

<Modal
  open={exportPromptOpen}
  title="查询成功！"
  onCancel={() => setExportPromptOpen(false)}
  footer={
    <Space>
      <Button onClick={() => setExportPromptOpen(false)}>关闭</Button>
      <Button onClick={() => handleSnapshotExport("json", lastResult)}>导出为 JSON</Button>
      <Button type="primary" onClick={() => handleSnapshotExport("csv", lastResult)}>
        导出为 CSV
      </Button>
    </Space>
  }
>
  共查询到 {lastResult?.rowCount ?? 0} 条记录，是否导出？
</Modal>
```

说明：
- “关闭”只关闭弹窗，不触发任何导出请求
- 仅点击“导出为 CSV/JSON”时调用导出接口

## 4. 数据格式规范

### 4.1 CSV 格式

**规则**:
- 当 `rowCount = 0` 时，返回 0 字节文件
- 当 `rowCount > 0` 时，第一行为列名
- 使用逗号分隔
- 字段包含逗号、换行符或引号时，使用双引号包裹
- 双引号转义：`"` → `""`
- NULL 值表示为空字符串
- 非空文件编码：UTF-8 with BOM（兼容 Excel）

**示例**:
```csv
id,name,email,created_at
1,John Doe,john@example.com,2024-01-01 10:00:00
2,"Smith, Jane",jane@example.com,2024-01-02 11:30:00
3,"Bob ""The Builder""",bob@example.com,2024-01-03 09:15:00
```

### 4.2 JSON 格式

**结构**:
```json
{
  "columns": ["列名数组"],
  "rows": [{"列名": "值"}],
  "rowCount": 100,
  "executionTimeMs": 150,
  "exportedAt": "ISO 8601 时间戳"
}
```

**数据类型映射**:
- 数字 → number
- 字符串 → string
- 布尔值 → boolean
- NULL → null
- 日期时间 → ISO 8601 字符串

## 5. 错误处理

### 5.1 后端错误

| 错误场景 | HTTP 状态码 | 错误信息 |
|---------|-----------|---------|
| 数据库连接不存在 | 404 | Database connection '{name}' not found |
| 查询接口 SQL 语法错误（`/query`） | 400 | SQL parse error: ... |
| 查询超时 | 500 | Query execution timeout |
| 不支持的格式 | 400 | Unsupported export format: {format} |
| 数据库连接失败 | 500 | Failed to connect to database |

### 5.2 前端错误处理

```typescript
try {
  const response = await exportQuerySnapshot(databaseName, result, format);
  // 下载逻辑...
} catch (error: any) {
  const detail = await parseBlobErrorDetail(error);
  if (error.response?.status === 404) {
    message.error("数据库连接不存在");
  } else if (error.response?.status === 400) {
    message.error(`请求错误: ${detail}`);
  } else if (error.response?.status === 500) {
    message.error("服务器错误，请稍后重试");
  } else {
    message.error(`导出失败: ${error.message}`);
  }
}

const parseBlobErrorDetail = async (error: any): Promise<string> => {
  const data = error?.response?.data;
  if (!(data instanceof Blob)) return error?.message || "Unknown error";
  const text = await data.text();
  try {
    return JSON.parse(text)?.detail || text;
  } catch {
    return text;
  }
};
```

## 6. 性能优化

### 6.1 流式响应

使用 `StreamingResponse` 避免导出内容在后端一次性拼接：

```python
def export_to_csv(result: QueryResult) -> Iterator[bytes]:
    # 逐行生成 CSV 内容
    for row in result.rows:
        yield csv_line
```

### 6.2 前端优化

- 使用 Blob API 处理大文件
- 导出时显示加载状态
- 快照导出不重新执行 SQL，直接导出当前结果集
- 限制单次快照导出最大行数（100,000 行，超限时前端提示并拒绝发起导出）

### 6.3 数据库查询优化

- 导出操作使用只读事务
- 添加查询超时限制（30 秒）
- 记录慢查询日志

## 7. 安全考虑

### 7.1 权限验证

- 导出操作需要数据库连接权限
- 验证用户是否有权访问指定数据库

### 7.2 SQL 注入防护

- 复用现有的 SQL 验证逻辑
- 禁止执行 DDL/DML 语句（仅允许 SELECT）

### 7.3 审计日志

```python
# 记录导出操作
logger.info(
    f"Export operation: user={user_id}, database={name}, "
    f"format={format}, rows={result.row_count}, source=snapshot"
)
```

## 8. 测试策略

### 8.1 单元测试

```python
# tests/unit/test_export_service.py

def test_export_to_csv():
    result = QueryResult(
        columns=[Column(name="id"), Column(name="name")],
        rows=[{"id": 1, "name": "John"}],
        rowCount=1,
        executionTimeMs=100
    )
    csv_content = list(ExportService.export_to_csv(result))
    assert b"id,name" in csv_content[0]
    assert b"1,John" in csv_content[1]

def test_export_empty_result_to_zero_byte():
    result = QueryResult(columns=[], rows=[], rowCount=0, executionTimeMs=10, sql="SELECT 1 WHERE 1=0")
    assert list(ExportService.export_to_csv(result)) == [b""]
    assert ExportService.export_to_json(result) == ""

def test_export_to_json():
    result = QueryResult(...)
    json_content = ExportService.export_to_json(result)
    data = json.loads(json_content)
    assert data["rowCount"] == 1
    assert "exportedAt" in data
```

### 8.2 集成测试

```python
# tests/integration/test_export_api.py

async def test_export_csv_endpoint(client, test_db):
    response = await client.post(
        "/api/v1/dbs/testdb/export/snapshot",
        json={
            "format": "csv",
            "sql": "SELECT * FROM users",
            "result": {
                "columns": [{"name": "id", "dataType": "integer"}],
                "rows": [{"id": 1}],
                "rowCount": 1,
                "executionTimeMs": 10,
                "sql": "SELECT * FROM users"
            }
        }
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "text/csv"
    assert "attachment" in response.headers["content-disposition"]
```

### 8.3 前端测试

```typescript
// src/components/__tests__/ExportButton.test.tsx

import { render, fireEvent, waitFor } from "@testing-library/react";
import { ExportButton } from "../ExportButton";

test("exports CSV when clicked", async () => {
  const { getByText } = render(
    <ExportButton
      databaseName="testdb"
      result={mockResult}
    />
  );

  fireEvent.click(getByText("导出"));
  fireEvent.click(getByText("导出为 CSV"));

  await waitFor(() => {
    expect(mockExportApi).toHaveBeenCalledWith("testdb", mockResult, "csv");
  });
});
```

## 9. 部署注意事项

### 9.1 环境变量

无需新增环境变量，复用现有配置。

### 9.2 依赖更新

后端无需新增依赖（使用 Python 标准库）。

### 9.3 数据库迁移

无需数据库 schema 变更。

## 10. 监控与日志

### 10.1 关键指标

- 导出请求总数
- 导出成功率
- 平均导出耗时
- 导出文件大小分布

### 10.2 日志格式

```
[INFO] Export started: database=mydb, format=csv, sql_length=150
[INFO] Export completed: database=mydb, format=csv, rows=1000, duration=1.5s
[ERROR] Export failed: database=mydb, error=connection timeout
```

## 11. 文档更新

需要更新以下文档：
- API 文档：添加导出接口说明
- 用户手册：添加导出功能使用指南
- README：更新功能列表
