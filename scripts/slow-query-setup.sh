#!/bin/bash
# ============================================================
# slow-query-setup.sh - MySQL 慢查询配置脚本
# 《MySQL 原理与实战》配套仓库
# ============================================================

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS="${MYSQL_PASS:-}"

mysql_exec() {
  if [ -n "$MYSQL_PASS" ]; then
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "$1"
  else
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -e "$1"
  fi
}

echo "=========================================="
echo " MySQL 慢查询配置"
echo "=========================================="

# 开启慢查询日志
echo ""
echo ">>> 开启慢查询日志..."
mysql_exec "
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 0.5;
SET GLOBAL slow_query_log_file = '/tmp/mysql-slow.log';
SET GLOBAL log_queries_not_using_indexes = 'ON';
SET GLOBAL min_examined_row_limit = 100;
"

echo ">>> 配置完成！"
echo ""
echo "当前配置："
mysql_exec "
SHOW VARIABLES WHERE Variable_name IN (
  'slow_query_log', 'long_query_time', 'slow_query_log_file',
  'log_queries_not_using_indexes', 'min_examined_row_limit'
);
"

echo ""
echo "=========================================="
echo " 验证方法："
echo "  1. 执行一条慢查询（如无索引的全表扫描）"
echo "  2. 查看慢查询日志："
echo "     tail -f /tmp/mysql-slow.log"
echo ""
echo " 使用 pt-query-digest 分析："
echo "     pt-query-digest /tmp/mysql-slow.log"
echo "=========================================="
