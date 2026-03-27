#!/bin/bash
# ============================================================
# benchmark.sh - MySQL 查询性能对比测试工具
# 《MySQL 原理与实战》配套仓库
# ============================================================

set -euo pipefail

# --- 配置 ---
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS="${MYSQL_PASS:-}"
MYSQL_DB="${MYSQL_DB:-learn_mysql}"
RUNS="${RUNS:-5}"           # 每条 SQL 运行次数
WARMUP="${WARMUP:-2}"       # 预热次数
OUTPUT="${OUTPUT:-benchmark_result.csv}"

# --- 工具函数 ---
mysql_exec() {
  if [ -n "$MYSQL_PASS" ]; then
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" -e "$1" 2>/dev/null
  else
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DB" -e "$1" 2>/dev/null
  fi
}

bench_query() {
  local label="$1"
  local sql="$2"
  local times=()
  
  echo -n "  测试 [$label] ... "
  
  # 预热
  for ((w=1; w<=WARMUP; w++)); do
    mysql_exec "$sql" > /dev/null 2>&1 || true
  done
  
  # 正式测试
  for ((r=1; r<=RUNS; r++)); do
    local start end elapsed
    start=$(date +%s%3N)
    mysql_exec "$sql" > /dev/null 2>&1
    end=$(date +%s%3N)
    elapsed=$((end - start))
    times+=("$elapsed")
  done
  
  # 计算统计
  local min max avg
  min=$(printf '%s\n' "${times[@]}" | sort -n | head -1)
  max=$(printf '%s\n' "${times[@]}" | sort -n | tail -1)
  avg=$(( ($(IFS=+; echo "${times[*]}") ) / RUNS ))
  
  echo "min=${min}ms max=${max}ms avg=${avg}ms"
  echo "$label,${min},${max},${avg}" >> "$OUTPUT"
}

# --- 使用说明 ---
usage() {
  echo "MySQL Benchmark 工具"
  echo ""
  echo "用法: $0 [选项] <SQL文件|SQL语句>"
  echo ""
  echo "选项:"
  echo "  -l LABEL    测试标签名"
  echo "  -r RUNS     运行次数 (默认: $RUNS)"
  echo "  -w WARMUP   预热次数 (默认: $WARMUP)"
  echo "  -o OUTPUT   输出文件 (默认: $OUTPUT)"
  echo "  -h          显示帮助"
  echo ""
  echo "环境变量:"
  echo "  MYSQL_HOST  MySQL 主机 (默认: 127.0.0.1)"
  echo "  MYSQL_PORT  MySQL 端口 (默认: 3306)"
  echo "  MYSQL_USER  MySQL 用户 (默认: root)"
  echo "  MYSQL_PASS  MySQL 密码"
  echo "  MYSQL_DB    数据库名 (默认: learn_mysql)"
  echo ""
  echo "示例:"
  echo "  $0 -l '全表扫描' 'SELECT * FROM user'"
  echo "  $0 -l '索引查询' -r 10 'SELECT * FROM user WHERE id = 1'"
  echo "  $0 -f benchmark_queries.sql"
  exit 0
}

# --- 主逻辑 ---
if [ $# -eq 0 ]; then
  usage
fi

LABEL="query"
SQL_FILE=""

while getopts "l:r:w:o:f:h" opt; do
  case $opt in
    l) LABEL="$OPTARG" ;;
    r) RUNS="$OPTARG" ;;
    w) WARMUP="$OPTARG" ;;
    o) OUTPUT="$OPTARG" ;;
    f) SQL_FILE="$OPTARG" ;;
    h) usage ;;
    \?) usage ;;
  esac
done
shift $((OPTIND-1))

# 初始化输出文件
echo "label,min(ms),max(ms),avg(ms)" > "$OUTPUT"

echo "=========================================="
echo " MySQL Benchmark"
echo " 数据库: $MYSQL_DB @ $MYSQL_HOST:$MYSQL_PORT"
echo " 运行次数: $RUNS (预热 $WARMUP)"
echo "=========================================="

if [ -n "$SQL_FILE" ]; then
  # 从文件读取多条 SQL 进行对比测试
  if [ ! -f "$SQL_FILE" ]; then
    echo "错误: 文件不存在 $SQL_FILE"
    exit 1
  fi
  
  while IFS='|' read -r label sql; do
    [ -z "$label" ] && continue
    [[ "$label" =~ ^# ]] && continue
    bench_query "$label" "$sql"
  done < "$SQL_FILE"
elif [ -n "$1" ]; then
  bench_query "$LABEL" "$1"
fi

echo ""
echo "=========================================="
echo " 结果已保存到: $OUTPUT"
echo "=========================================="
cat "$OUTPUT" | column -t -s','
