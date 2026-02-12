/** 执行并导出按钮组件 */

import React, { useState } from "react";
import { Button, Dropdown, message } from "antd";
import { ThunderboltOutlined } from "@ant-design/icons";
import type { MenuProps } from "antd";
import { QueryResult } from "../types/query";
import { apiClient, exportQuerySnapshot, downloadBlobFromResponse } from "../services/api";

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
      // 1. 先执行查询并在页面展示结果
      const queryResponse = await apiClient.post<QueryResult>(
        `/api/v1/dbs/${databaseName}/query`,
        { sql: sql.trim() }
      );
      const queryResult = queryResponse.data;

      // 2. 将结果渲染到页面
      onResult?.(queryResult);

      // 3. 再导出同一份结果快照
      const exportResponse = await exportQuerySnapshot(databaseName, queryResult, format);
      downloadBlobFromResponse(exportResponse);

      message.success(`执行并导出 ${format.toUpperCase()} 成功`);
      onSuccess?.();
    } catch (error: any) {
      const errorMessage =
        error.response?.data?.detail || error.message || "执行失败";
      message.error(`执行失败: ${errorMessage}`);
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
