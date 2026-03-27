-- ============================================================
-- 案例 28: FOR UPDATE 锁范围
-- 对应章节: 第 25 章 - 锁机制——MySQL 的"交通规则"
-- MySQL 版本: 8.0+
-- ============================================================
-- 本案例演示:
--   1. 主键等值查询的锁范围（行锁）
--   2. 唯一索引等值查询的锁范围
--   3. 非唯一索引等值查询的锁范围（Next-Key Lock）
--   4. 范围查询的锁范围
--   5. 无索引查询退化为表锁
--   6. 间隙锁（Gap Lock）演示
-- ============================================================

-- 1. 准备环境
CREATE DATABASE IF NOT EXISTS learn_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE learn_mysql;

-- 2. 创建表结构

DROP TABLE IF EXISTS lock_test;
CREATE TABLE lock_test (
    id INT PRIMARY KEY AUTO_INCREMENT,
    c1 INT NOT NULL,
    c2 VARCHAR(50),
    KEY idx_c1 (c1)
) ENGINE=InnoDB;

-- 3. 插入测试数据

-- 插入不连续的 ID，方便观察间隙锁
INSERT INTO lock_test (id, c1, c2) VALUES
(1, 10, 'a'),
(5, 20, 'b'),
(10, 30, 'c'),
(15, 40, 'd'),
(20, 50, 'e');

-- ============================================================
-- 4. 问题 SQL（容易被误解的锁范围）
-- ============================================================

-- 4.1 【常见误解】认为 FOR UPDATE 只锁一行
-- 实际上锁的范围取决于: 查询条件、索引类型、隔离级别
-- 在 REPEATABLE READ 隔离级别下，默认使用 Next-Key Lock

-- 4.2 【问题】非唯一索引等值查询 —— 锁的不止一行
-- 查询 c1 = 20（存在），实际加锁范围: (10, 20] + (20, 30)
-- 即 Next-Key Lock [10, 30)
-- 这意味着 id=1 和 id=10 之间的间隙也被锁住了

-- 4.3 【问题】范围查询 —— 锁住更大的范围
-- 查询 c1 BETWEEN 20 AND 40
-- 实际加锁范围: (10, 50]，比想象的大得多

-- 4.4 【问题】无索引列查询 —— 退化为表锁
-- 如果查询条件列没有索引，InnoDB 会对所有行加锁
-- 等于锁住了整张表

-- ============================================================
-- 5. 优化 SQL + 锁范围分析
-- ============================================================

-- 重要: 以下测试需要两个 MySQL 连接（会话）来验证锁范围
-- 会话 A: 执行加锁查询
-- 会话 B: 尝试在不同位置插入/更新，验证是否被阻塞

-- ============================================================
-- 场景 1: 主键等值查询 —— 行锁
-- ============================================================
-- 会话 A:
-- BEGIN;
-- SELECT * FROM lock_test WHERE id = 10 FOR UPDATE;
-- 实际加锁: 行锁 on id=10（注意不是 Next-Key Lock，因为主键是唯一的）

-- 会话 B: 以下操作会被阻塞
-- SELECT * FROM lock_test WHERE id = 10 FOR UPDATE;  -- 等待行锁
-- UPDATE lock_test SET c2 = 'x' WHERE id = 10;       -- 等待行锁

-- 会话 B: 以下操作不受影响
-- SELECT * FROM lock_test WHERE id = 5 FOR UPDATE;   -- 不阻塞
-- INSERT INTO lock_test (c1, c2) VALUES (12, 'new');  -- 不阻塞（主键等值命中，只加行锁，不加间隙锁）

-- ============================================================
-- 场景 2: 非唯一索引等值查询 —— Next-Key Lock
-- ============================================================
-- 会话 A:
-- BEGIN;
-- SELECT * FROM lock_test WHERE c1 = 20 FOR UPDATE;
-- 实际加锁范围:
--   - Next-Key Lock (10, 20] → 锁住 c1=20 的记录及左间隙
--   - Gap Lock (20, 30)      → 锁住右间隙（防止幻读）
-- 总锁范围: (10, 30)

-- 会话 B: 以下操作会被阻塞
-- INSERT INTO lock_test (c1, c2) VALUES (15, 'blocked');  -- 在间隙 (10, 30) 内插入，被阻塞！
-- INSERT INTO lock_test (c1, c2) VALUES (25, 'blocked');  -- 在间隙 (10, 30) 内插入，被阻塞！
-- UPDATE lock_test SET c2 = 'x' WHERE c1 = 20;            -- 锁住的行，被阻塞

-- 会话 B: 以下操作不受影响
-- INSERT INTO lock_test (c1, c2) VALUES (5, 'ok');       -- 在间隙外，不阻塞
-- INSERT INTO lock_test (c1, c2) VALUES (35, 'ok');      -- 在间隙外，不阻塞

-- ============================================================
-- 场景 3: 非唯一索引等值查询（值不存在）—— 间隙锁
-- ============================================================
-- 会话 A:
-- BEGIN;
-- SELECT * FROM lock_test WHERE c1 = 25 FOR UPDATE;
-- c1=25 不存在，InnoDB 加锁范围: (20, 30) 的间隙锁

-- 会话 B: 以下操作会被阻塞
-- INSERT INTO lock_test (c1, c2) VALUES (25, 'blocked');  -- 在间隙内插入，被阻塞！

-- 会话 B: 以下操作不受影响
-- UPDATE lock_test SET c2 = 'x' WHERE c1 = 20;            -- 不在间隙内
-- UPDATE lock_test SET c2 = 'x' WHERE c1 = 30;            -- 不在间隙内

-- ============================================================
-- 场景 4: 范围查询 —— 更大的锁范围
-- ============================================================
-- 会话 A:
-- BEGIN;
-- SELECT * FROM lock_test WHERE c1 >= 20 AND c1 <= 40 FOR UPDATE;
-- 实际加锁范围: (10, 50]
-- 包含: Next-Key Lock (10, 20], (20, 30], (30, 40] + Gap Lock (40, 50)

-- 会话 B: 以下操作都会被阻塞
-- INSERT INTO lock_test (c1, c2) VALUES (15, 'blocked');  -- 在 (10, 50) 内
-- INSERT INTO lock_test (c1, c2) VALUES (25, 'blocked');  -- 在 (10, 50) 内
-- INSERT INTO lock_test (c1, c2) VALUES (35, 'blocked');  -- 在 (10, 50) 内
-- INSERT INTO lock_test (c1, c2) VALUES (45, 'blocked');  -- 在 (10, 50) 内

-- ============================================================
-- 场景 5: 无索引查询 —— 表锁
-- ============================================================
-- 会话 A:
-- BEGIN;
-- SELECT * FROM lock_test WHERE c2 = 'c' FOR UPDATE;
-- c2 没有索引，InnoDB 对所有行和间隙加锁 → 等于表锁

-- 会话 B: 所有插入和更新都会被阻塞
-- INSERT INTO lock_test (c1, c2) VALUES (100, 'blocked');  -- 被阻塞！
-- UPDATE lock_test SET c2 = 'x' WHERE id = 1;               -- 被阻塞！

-- ============================================================
-- 场景 6: 间隙锁只防插入，不防读写
-- ============================================================
-- 间隙锁之间不冲突！两个事务可以对同一个间隙加间隙锁
-- 但都不能在这个间隙中插入数据

-- 会话 A:
-- BEGIN;
-- SELECT * FROM lock_test WHERE c1 = 25 FOR UPDATE;  -- 间隙锁 (20, 30)

-- 会话 B:
-- BEGIN;
-- SELECT * FROM lock_test WHERE c1 = 25 FOR UPDATE;  -- 间隙锁 (20, 30) ← 不冲突！
-- INSERT INTO lock_test (c1, c2) VALUES (25, 'blocked');  -- 被自己的间隙锁阻塞！

-- ============================================================
-- 6. 验证对比（EXPLAIN + 锁信息查看）
-- ============================================================

-- 6.1 使用 EXPLAIN 查看执行计划
EXPLAIN SELECT * FROM lock_test WHERE id = 10 FOR UPDATE;
-- type=const, key=PRIMARY, rows=1

EXPLAIN SELECT * FROM lock_test WHERE c1 = 20 FOR UPDATE;
-- type=ref, key=idx_c1, rows=1

EXPLAIN SELECT * FROM lock_test WHERE c2 = 'c' FOR UPDATE;
-- type=ALL, key=NULL, rows=5 ← 全表扫描

-- 6.2 查看当前锁等待情况
-- 在会话 B 被阻塞时，在第三个会话中执行:
-- SELECT * FROM performance_schema.data_lock_waits;
-- SELECT * FROM performance_schema.data_locks
-- WHERE OBJECT_NAME = 'lock_test';

-- 6.3 查看事务状态
-- SELECT * FROM information_schema.INNODB_TRX;

-- ============================================================
-- 7. 清理
-- ============================================================

-- 确保没有活跃事务
-- ROLLBACK;  -- 在所有会话中执行

DROP TABLE IF EXISTS lock_test;
