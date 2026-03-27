#!/bin/bash
# ============================================================
# explain-analyzer.sh - MySQL Explain 输出格式化工具
# 《MySQL 原理与实战》配套仓库
# ============================================================

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS="${MYSQL_PASS:-}"
MYSQL_DB="${MYSQL_DB:-learn_mysql}"

mysql_exec() {
  if [ -n "$MYSQL_PASS" ]; then
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" --table -e "$1"
  else
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DB" --table -e "$1"
  fi
}

usage() {
  echo "MySQL Explain 格式化分析工具"
  echo ""
  echo "用法: $0 <SQL语句>"
  echo ""
  echo "功能:"
  echo "  1. 输出格式化的 EXPLAIN 结果"
  echo "  2. 标记潜在问题（全表扫描、临时表、文件排序）"
  echo "  3. 同时输出 EXPLAIN ANALYZE（MySQL 8.0+）"
  echo ""
  echo "环境变量: MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASS MYSQL_DB"
  echo ""
  echo "示例:"
  echo "  $0 'SELECT * FROM user WHERE id = 1'"
  echo "  $0 'SELECT * FROM orders WHERE user_id = 1 ORDER BY created_at DESC LIMIT 10'"
  exit 0
}

if [ $# -eq 0 ]; then
  usage
fi

SQL="$1"

echo "=========================================="
echo " SQL: $SQL"
echo " 数据库: $MYSQL_DB @ $MYSQL_HOST:$MYSQL_PORT"
echo "=========================================="
echo ""

# 1. 标准 EXPLAIN
echo ">>> EXPLAIN:"
echo ""
mysql_exec "EXPLAIN FORMAT=JSON $SQL" 2>/dev/null || mysql_exec "EXPLAIN $SQL"

echo ""
echo ">>> EXPLAIN ANALYZE (MySQL 8.0+):"
echo ""
mysql_exec "EXPLAIN ANALYZE $SQL" 2>/dev/null || echo "  (EXPLAIN ANALYZE 不可用，需要 MySQL 8.0.18+)"

echo ""
echo "=========================================="
echo " 问题检查:"
echo "=========================================="

# 检查全表扫描
FULL_SCAN=$(mysql_exec "EXPLAIN $SQL" 2>/dev/null | grep -c "ALL" || true)
if [ "$FULL_SCAN" -gt 0 ]; then
  echo "  ⚠️  发现 $FULL_SCAN 处全表扫描 (type=ALL)"
fi

# 检查临时表
TEMP_TABLE=$(mysql_exec "EXPLAIN $SQL" 2>/dev/null | grep -c "Using temporary" || true)
if [ "$TEMP_TABLE" -gt 0 ]; then
  echo "  ⚠️  发现 $TEMP_TABLE 处使用临时表 (Using temporary)"
fi

# 检查文件排序
FILESORT=$(mysql_exec "EXPLAIN $SQL" 2>/dev/null | grep -c "Using filesort" || true)
if [ "$FILESORT" -gt 0 ]; then
  echo "  ⚠️  发现 $FILESORT 处文件排序 (Using filesort)"
fi

if [ "$FULL_SCAN" -eq 0 ] && [ "$TEMP_TABLE" -eq 0 ] && [ "$FILESORT" -eq 0 ]; then
  echo "  ✅ 未发现明显性能问题"
fi

echo ""
echo "=========================================="
