-- ============================================================
-- perf-schema-dashboard.sql - performance_schema 监控面板
-- 《MySQL 原理与实战》配套仓库
-- 适用版本：MySQL 8.0.28+
-- ============================================================

USE learn_mysql;

-- ============================================================
-- 1. 确认 performance_schema 已启用
-- ============================================================
SELECT @@performance_schema AS perf_schema_enabled;

-- ============================================================
-- 2. 当前正在执行的语句
-- ============================================================
SELECT * FROM performance_schema.events_waits_current
WHERE EVENT_NAME LIKE 'statement/sql/%'
LIMIT 10;

-- ============================================================
-- 3. 最近 10 条最慢的 SQL（按延迟排序）
-- ============================================================
SELECT 
  DIGEST_TEXT AS 'SQL摘要',
  COUNT_STAR AS '执行次数',
  ROUND(AVG_TIMER_WAIT / 1000000000000, 2) AS '平均耗时(s)',
  ROUND(MAX_TIMER_WAIT / 1000000000000, 2) AS '最大耗时(s)',
  ROUND(SUM_ROWS_EXAMINED / COUNT_STAR) AS '平均扫描行数',
  ROUND(SUM_ROWS_SENT / COUNT_STAR) AS '平均返回行数'
FROM performance_schema.events_statements_summary_by_digest
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 10;

-- ============================================================
-- 4. 全表扫描 TOP 10
-- ============================================================
SELECT 
  DIGEST_TEXT AS 'SQL摘要',
  COUNT_STAR AS '执行次数',
  SUM_NO_INDEX_USED AS '无索引使用次数',
  SUM_NO_GOOD_INDEX_USED AS '无合适索引次数',
  ROUND(SUM_ROWS_EXAMINED / COUNT_STAR) AS '平均扫描行数'
FROM performance_schema.events_statements_summary_by_digest
WHERE SUM_NO_INDEX_USED > 0 OR SUM_NO_GOOD_INDEX_USED > 0
ORDER BY SUM_ROWS_EXAMINED DESC
LIMIT 10;

-- ============================================================
-- 5. 等待事件 TOP 10（找出性能瓶颈）
-- ============================================================
SELECT 
  EVENT_NAME AS '事件',
  COUNT_STAR AS '等待次数',
  ROUND(SUM_TIMER_WAIT / 1000000000000, 2) AS '总等待(s)',
  ROUND(AVG_TIMER_WAIT / 1000000000, 2) AS '平均等待(ms)'
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE COUNT_STAR > 0
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- ============================================================
-- 6. 表 I/O 统计
-- ============================================================
SELECT 
  OBJECT_SCHEMA AS '数据库',
  OBJECT_NAME AS '表名',
  COUNT_READ AS '读次数',
  COUNT_WRITE AS '写次数',
  ROUND(SUM_TIMER_READ / 1000000000000, 2) AS '总读耗时(s)',
  ROUND(SUM_TIMER_WRITE / 1000000000000, 2) AS '总写耗时(s)'
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA = 'learn_mysql'
ORDER BY SUM_TIMER_READ + SUM_TIMER_WRITE DESC
LIMIT 20;

-- ============================================================
-- 7. 索引使用统计
-- ============================================================
SELECT 
  OBJECT_SCHEMA AS '数据库',
  OBJECT_NAME AS '表名',
  INDEX_NAME AS '索引名',
  COUNT_READ AS '读次数',
  COUNT_WRITE AS '写次数',
  COUNT_FETCH AS '返回行数'
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'learn_mysql'
  AND INDEX_NAME IS NOT NULL
ORDER BY COUNT_READ DESC
LIMIT 20;

-- ============================================================
-- 8. 未使用的索引（可考虑删除）
-- ============================================================
SELECT 
  OBJECT_SCHEMA AS '数据库',
  OBJECT_NAME AS '表名',
  INDEX_NAME AS '索引名'
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'learn_mysql'
  AND INDEX_NAME IS NOT NULL
  AND COUNT_READ = 0
  AND COUNT_WRITE = 0
ORDER BY OBJECT_NAME, INDEX_NAME;

-- ============================================================
-- 9. 内存使用概览
-- ============================================================
SELECT 
  EVENT_NAME AS '内存类型',
  CURRENT_ALLOCATED AS '当前分配(bytes)',
  ROUND(CURRENT_ALLOCATED / 1024 / 1024, 2) AS '当前分配(MB)'
FROM performance_schema.memory_summary_global_by_event_name
WHERE CURRENT_ALLOCATED > 0
ORDER BY CURRENT_ALLOCATED DESC
LIMIT 15;

-- ============================================================
-- 10. 连接统计
-- ============================================================
SELECT 
  '当前连接数' AS metric, COUNT(*) AS value 
FROM information_schema.PROCESSLIST
UNION ALL
SELECT 
  '最大历史连接数', VARIABLE_VALUE 
FROM information_schema.GLOBAL_STATUS 
WHERE VARIABLE_NAME = 'Max_used_connections'
UNION ALL
SELECT 
  '连接错误数', VARIABLE_VALUE 
FROM information_schema.GLOBAL_STATUS 
WHERE VARIABLE_NAME = 'Connection_errors_max_connections';
