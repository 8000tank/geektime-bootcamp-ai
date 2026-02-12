/** 导出按钮组件 */

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
