#!/bin/bash

# Setup Interview Database (WSL2/Ubuntu)
# 在 WSL2 中创建和初始化面试管理数据库
# 使用 sudo mysql 以适配 Ubuntu 默认 auth_socket 认证

set -e

echo "========================================="
echo "  Interview Database Setup (WSL2)"
echo "========================================="
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ubuntu/WSL2 默认 root 使用 auth_socket，需用 sudo mysql
MYSQL_CMD="sudo mysql"

echo "Step 1: Creating database schema..."
$MYSQL_CMD < "$SCRIPT_DIR/create_interview_db.sql"
echo "✓ Database schema created"

echo ""
echo "Step 2: Loading seed data (Part 1)..."
$MYSQL_CMD < "$SCRIPT_DIR/seed_interview_data.sql"
echo "✓ Seed data part 1 loaded"

echo ""
echo "Step 3: Loading seed data (Part 2)..."
$MYSQL_CMD < "$SCRIPT_DIR/seed_interview_data_part2.sql"
echo "✓ Seed data part 2 loaded"

echo ""
echo "Step 4: Loading seed data (Part 3)..."
$MYSQL_CMD < "$SCRIPT_DIR/seed_interview_data_part3.sql"
echo "✓ Seed data part 3 loaded"

echo ""
echo "========================================="
echo "  Database Statistics"
echo "========================================="
$MYSQL_CMD -e "
USE interview_db;
SELECT 'Departments' AS table_name, COUNT(*) AS count FROM departments
UNION ALL SELECT 'Job Positions', COUNT(*) FROM job_positions
UNION ALL SELECT 'Candidates', COUNT(*) FROM candidates
UNION ALL SELECT 'Applications', COUNT(*) FROM applications
UNION ALL SELECT 'Interviewers', COUNT(*) FROM interviewers
UNION ALL SELECT 'Interview Rounds', COUNT(*) FROM interview_rounds
UNION ALL SELECT 'Interviews', COUNT(*) FROM interviews
UNION ALL SELECT 'Interview Assignments', COUNT(*) FROM interview_assignments
UNION ALL SELECT 'Interview Feedback', COUNT(*) FROM interview_feedback
UNION ALL SELECT 'Offers', COUNT(*) FROM offers
UNION ALL SELECT 'Background Checks', COUNT(*) FROM background_checks
UNION ALL SELECT 'Activity Logs', COUNT(*) FROM activity_logs;
"

echo ""
echo "Creating app user (dbquery/dbquery) for db_query tool..."
$MYSQL_CMD -e "
CREATE USER IF NOT EXISTS 'dbquery'@'localhost' IDENTIFIED BY 'dbquery';
GRANT ALL PRIVILEGES ON interview_db.* TO 'dbquery'@'localhost';
FLUSH PRIVILEGES;
" 2>/dev/null || echo "  (若用户已存在可忽略)"

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "在 db_query 前端添加连接时使用："
echo "  URL: mysql://dbquery:dbquery@localhost:3306/interview_db"
echo ""
