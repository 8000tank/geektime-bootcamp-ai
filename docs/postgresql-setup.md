# PostgreSQL 安装和配置指南

本指南适用于在 WSL2 (Ubuntu) 环境下安装和配置 PostgreSQL，用于支持 Project Alpha 项目运行。

## 1. 安装 PostgreSQL

```bash
# 更新包列表
sudo apt update

# 安装 PostgreSQL 和相关工具
sudo apt install postgresql postgresql-contrib

# 验证安装
psql --version
```

## 2. 启动 PostgreSQL 服务

```bash
# 启动服务
sudo service postgresql start

# 设置开机自启（可选）
sudo systemctl enable postgresql

# 检查服务状态
sudo service postgresql status
```

## 3. 配置 postgres 用户密码

```bash
# 切换到 postgres 用户
sudo -u postgres psql

# 在 PostgreSQL 命令行中执行
ALTER USER postgres WITH PASSWORD 'wy13579';

# 退出
\q
```

或者使用一行命令：
```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'wy13579';"
```

## 4. 创建项目数据库

```bash
# 创建 projectalpha 数据库
sudo -u postgres createdb projectalpha

# 验证数据库创建成功
sudo -u postgres psql -l
```

## 5. 测试数据库连接

```bash
# 使用新密码连接 PostgreSQL
psql -h localhost -U postgres -d projectalpha

# 成功后应看到 projectalpha# 提示符
# 输入 \q 退出
```

## 6. 配置项目环境变量

在 `backend/.env` 文件中配置：

```env
DATABASE_URL=postgresql://postgres:wy13579@localhost:5432/projectalpha
API_V1_PREFIX=/api/v1
PROJECT_NAME=Project Alpha
ALLOWED_ORIGINS=http://localhost:5173
ENVIRONMENT=development
```

## 7. 运行数据库迁移

```bash
cd backend

# 运行所有迁移
uv run alembic upgrade head

# 查看迁移历史（可选）
uv run alembic history

# 查看当前版本（可选）
uv run alembic current
```

## 8. 验证配置

```bash
# 测试后端连接
cd backend
uv run python -c "
from app.core.database import engine
from sqlalchemy import text
async def test():
    async with engine.begin() as conn:
        result = await conn.execute(text('SELECT version()'))
        print('PostgreSQL 连接成功!')
        print(result.scalar())
import asyncio
asyncio.run(test())
"
```

## 常见问题

### 问题1：无法连接到 PostgreSQL

**错误信息**：`connection to server at "localhost" (127.0.0.1), port 5432 failed`

**解决方案**：
```bash
# 确保服务运行
sudo service postgresql status

# 如果没有运行，启动它
sudo service postgresql start

# 检查端口监听
sudo netstat -an | grep 5432
```

### 问题2：密码认证失败

**错误信息**：`FATAL: password authentication failed for user "postgres"`

**解决方案**：
```bash
# 重置密码
sudo -u postgres psql
ALTER USER postgres WITH PASSWORD 'wy13579';
\q
```

### 问题3：权限被拒绝

**错误信息**：`permission denied for database`

**解决方案**：
```bash
# 确保使用正确的用户
sudo -u postgres createdb projectalpha

# 或给当前用户授权
sudo -u postgres psql
CREATE USER your_username WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE projectalpha TO your_username;
\q
```

## 附加配置（可选）

### 配置 PostgreSQL 允许远程连接

编辑配置文件：
```bash
sudo nano /etc/postgresql/*/main/postgresql.conf
```
修改：
```
listen_addresses = 'localhost'  # 或 '*' 允许所有IP
```

编辑 pg_hba.conf：
```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf
```
添加：
```
host    all             all             127.0.0.1/32            md5
```

重启服务：
```bash
sudo service postgresql restart
```

### 创建数据库用户（可选）

为了更好的安全性，可以创建专门的数据库用户：

```bash
sudo -u postgres psql
CREATE USER projectalpha_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE projectalpha TO projectalpha_user;
\q
```

然后在 `.env` 中使用：
```env
DATABASE_URL=postgresql://projectalpha_user:your_password@localhost:5432/projectalpha
```

## 完成后的下一步

PostgreSQL 安装配置完成后，您可以：

1. 运行 `make w1-start` 启动 Project Alpha 项目
2. 访问 http://localhost:5173 查看应用
3. 访问 http://localhost:8000/api/v1/docs 查看 API 文档

## 参考链接

- [PostgreSQL 官方文档](https://www.postgresql.org/docs/)
- [Ubuntu PostgreSQL 安装指南](https://ubuntu.com/server/docs/databases-postgresql)