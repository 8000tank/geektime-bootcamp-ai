"""数据导出服务模块"""

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
            CSV 内容的字节块
        """
        if result.rowCount == 0:
            # PRD 约定：空结果返回 0 字节文件
            yield b""
            return

        # 非空结果使用 UTF-8 with BOM，保证 Excel 打开兼容
        output = StringIO()
        writer = csv.writer(output, quoting=csv.QUOTE_MINIMAL)

        # 写入表头
        headers = [col.name for col in result.columns]
        writer.writerow(headers)
        # 添加 BOM 标记
        yield ("\ufeff" + output.getvalue()).encode("utf-8")
        output.truncate(0)
        output.seek(0)

        # 写入数据行
        for row in result.rows:
            values = [row.get(col.name) for col in result.columns]
            # 处理 None 值
            values = ["" if v is None else str(v) for v in values]
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
            JSON 字符串（空结果返回空字符串）
        """
        if result.rowCount == 0:
            # PRD 约定：空结果返回 0 字节文件
            return ""

        export_data = {
            "columns": [col.name for col in result.columns],
            "rows": result.rows,
            "rowCount": result.rowCount,
            "executionTimeMs": result.executionTimeMs,
            "exportedAt": datetime.utcnow().isoformat() + "Z",
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
            文件名字符串，格式：{database_name}_query_{timestamp}.{format}
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{database_name}_query_{timestamp}.{format}"
