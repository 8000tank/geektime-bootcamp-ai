# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个极客时间AI训练营的项目仓库，包含多个子项目：

- **w1/project-alpha**: 基于标签的Ticket管理系统（FastAPI + React）
- **w2/db_query**: 数据库查询工具，支持自然语言转SQL（FastAPI + Refine）
- **w3/raflow**: 实时语音听写工具（Tauri + Rust + React）
- **site**: 项目展示网站（Astro）

## 常用开发命令

### 通用命令（从根目录）

```bash
# 查看帮助
make help

# W1 Project Alpha
make w1-install    # 安装w1所有依赖
make w1-start      # 启动w1后端和前端
make w1-stop       # 停止w1服务
make w1-build      # 构建w1前端
make w1-clean      # 清理w1进程和临时文件

# Site（文档网站）
make site-start    # 启动site开发服务器
make site-stop     # 停止site服务
```

### W1 Project Alpha - Ticket管理系统

```bash
cd w1/project-alpha

# 后端
cd backend
uv sync                    # 安装依赖
uv run uvicorn app.main:app --reload --port 8000  # 启动开发服务器
uv run pytest              # 运行测试
uv run black app/           # 代码格式化
uv run isort app/           # 导入排序
uv run mypy app/            # 类型检查

# 前端
cd frontend
yarn install               # 安装依赖
yarn dev                   # 启动开发服务器（localhost:5173）
yarn build                 # 构建生产版本
yarn lint                  # 代码检查
```

### W2 Database Query Tool

```bash
cd w2/db_query

# 使用Makefile（推荐）
make install               # 安装所有依赖
make setup                 # 初始设置（包括数据库迁移）
make dev                   # 启动后端和前端
make dev-backend           # 仅启动后端（localhost:8000）
make dev-frontend          # 仅启动前端（localhost:5173）
make test                  # 运行所有测试
make lint                  # 代码检查
make format                # 代码格式化
make health                # 检查后端健康状态
make docs                  # 打开API文档

# 数据库迁移
make db-upgrade            # 应用迁移
make db-migrate MESSAGE="描述"  # 创建新迁移
```

### W3 RAFlow - 实时语音听写工具

```bash
cd w3/raflow

yarn install               # 安装依赖
yarn tauri dev            # 开发模式
yarn tauri build          # 生产构建

# Rust相关
cargo test --all-features  # 运行测试
cargo fmt                  # 格式化代码
cargo clippy               # 代码检查
```

### Site - 项目文档网站

```bash
cd site

yarn install               # 安装依赖
yarn dev                   # 开发服务器（localhost:4321）
yarn build                 # 构建生产版本
yarn preview               # 预览构建结果
```

## 项目架构

### W1 Project Alpha架构

- **后端**: FastAPI + SQLAlchemy + PostgreSQL + Alembic
  - `app/api/`: API路由
  - `app/crud/`: 数据库操作
  - `app/models/`: SQLAlchemy模型
  - `app/schemas/`: Pydantic数据模型
  - `app/utils/`: 工具函数
- **前端**: React + TypeScript + Vite + TailwindCSS + Shadcn UI
  - 状态管理：Zustand
  - 数据获取：Axios
  - 通知：Sonner

### W2 Database Query Tool架构

- **后端**: FastAPI + SQLModel + 自然语言处理
  - `app/api/v1/`: API路由（databases, queries）
  - `app/adapters/`: 数据库适配器（PostgreSQL, MySQL）
  - `app/services/`: 核心服务（nl2sql, query_wrapper, metadata）
  - `app/models/`: 数据模型
- **前端**: React + Refine 5 + Ant Design + Monaco Editor
  - 提供数据库连接管理和SQL查询界面

### W3 RAFlow架构

- **后端**: Rust + Tauri 2.1
  - `src-tauri/src/audio/`: 音频采集与处理
  - `src-tauri/src/network/`: WebSocket通信
  - `src-tauri/src/input/`: 文本注入
  - `src-tauri/src/system/`: 系统集成（热键、窗口、托盘）
- **前端**: React + TypeScript + TailwindCSS
  - 使用Zustand进行状态管理

## 开发环境

- **Python**: 使用uv管理Python依赖
- **Node.js**: 使用yarn管理前端依赖
- **数据库**: PostgreSQL（w1, w2）
- **Rust**: 1.90+（w3）
- **环境**: Win11下的WSL2，conda虚拟环境"words_312"

## API文档

- **W1**: http://localhost:8000/api/v1/docs
- **W2**: http://localhost:8000/docs

## 测试

- **后端测试**: 使用pytest，支持异步测试
- **前端测试**: 使用vitest（w2, w3）
- **Rust测试**: 使用cargo test和cargo nextest（w3）

## 代码质量

- **Python**: 使用black、isort、mypy
- **TypeScript**: 使用ESLint、Prettier
- **Rust**: 使用cargo fmt、cargo clippy
- 所有项目都配置了pre-commit hooks

## 重要说明

1. 所有对话和文档都使用中文
2. 创建测试文件时放在`tests`目录下
3. 创建说明文档时放在`docs`目录下
4. 修改代码时不要将中文双引号改为英文双引号
5. 实现需求前先仔细思考，给出分析思路