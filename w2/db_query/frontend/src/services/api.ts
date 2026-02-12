/** Axios API client instance. */

import axios, { AxiosResponse } from "axios";
import { QueryResult } from "../types/query";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

// Request interceptor
apiClient.interceptors.request.use(
  (config) => {
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor
apiClient.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    // Handle common errors
    if (error.response) {
      const message =
        error.response.data?.detail || error.response.data?.error || "An error occurred";
      console.error("API Error:", message);
    }
    return Promise.reject(error);
  }
);

/**
 * 导出查询结果快照
 */
export async function exportQuerySnapshot(
  databaseName: string,
  result: QueryResult,
  format: "csv" | "json"
): Promise<AxiosResponse<Blob>> {
  return apiClient.post(
    `/api/v1/dbs/${databaseName}/export/snapshot`,
    { sql: result.sql, format, result },
    { responseType: "blob" }
  );
}

/**
 * 从响应中下载 Blob 文件
 */
export function downloadBlobFromResponse(response: AxiosResponse<Blob>): void {
  const contentDisposition = response.headers["content-disposition"];
  let filename = "export";
  if (contentDisposition) {
    const match = contentDisposition.match(/filename="?([^"]+)"?/);
    if (match) {
      filename = match[1];
    }
  }

  const url = window.URL.createObjectURL(new Blob([response.data]));
  const link = document.createElement("a");
  link.href = url;
  link.setAttribute("download", filename);
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.URL.revokeObjectURL(url);
}
