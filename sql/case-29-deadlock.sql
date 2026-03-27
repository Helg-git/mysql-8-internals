-- ============================================================
-- 案例 29: 死锁复现与排查
-- 对应章节: 第 25 章 锁机制
-- MySQL 版本: 8.0+
-- 说明: 演示经典的 AB-BA 死锁场景，学习如何排查和解决
-- ============================================================

-- 1. 准备环境
DROP DATABASE IF EXISTS case_deadlock;
CREATE DATABASE case_deadlock;
USE case_deadlock;

-- 2. 创建表结构
CREATE TABLE account (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    version INT NOT NULL DEFAULT 0,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_balance (balance)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 插入测试数据
INSERT INTO account (name, balance) VALUES
('Alice', 10000.00),
('Bob',   10000.00),
('Charlie', 5000.00);

SELECT * FROM account;

-- ============================================================
-- 3. 死锁复现（需要两个 MySQL 会话）
-- ============================================================

-- ===== 会话 A（终端 1）=====
-- 开启事务，锁定 Alice 的行
BEGIN;
UPDATE account SET balance = balance - 100 WHERE name = 'Alice';
-- 会话 A 现在持有 Alice 行的 X 锁

-- ===== 会话 B（终端 2）=====
-- 开启事务，锁定 Bob 的行
BEGIN;
UPDATE account SET balance = balance - 100 WHERE name = 'Bob';
-- 会话 B 现在持有 Bob 行的 X 锁

-- ===== 会话 A（终端 1）=====
-- 尝试锁定 Bob 的行 —— 会被阻塞！
UPDATE account SET balance = balance + 100 WHERE name = 'Bob';
-- 会话 A 在等待会话 B 释放 Bob 的锁

-- ===== 会话 B（终端 2）=====
-- 尝试锁定 Alice 的行 —— 死锁！MySQL 会检测到并回滚其中一个事务
UPDATE account SET balance = balance + 100 WHERE name = 'Alice';
-- 预期输出：ERROR 1213 (40001): Deadlock found when trying to get lock;
--           try restarting transaction

-- ===== 会话 A（终端 1）=====
-- 如果会话 A 存活，提交事务
COMMIT;

-- ===== 会话 B（终端 2）=====
-- 会话 B 被回滚，需要重新执行
ROLLBACK;

-- ============================================================
-- 4. 死锁排查
-- ============================================================

-- 查看最近一次死锁信息
SHOW ENGINE INNODB STATUS\G

-- 关键信息解读：
-- 1. LATEST DETECTED DEADLOCK — 最近一次死锁详情
-- 2. TRANSACTION 1 / TRANSACTION 2 — 两个事务的持有锁和等待锁
-- 3. HOLDS THE LOCK — 持有的锁
-- 4. WAITING FOR THIS LOCK TO BE GRANTED — 等待的锁
-- 5. WE ROLL BACK TRANSACTION — MySQL 回滚了哪个事务

-- ============================================================
-- 5. 解决方案对比
-- ============================================================

-- 方案一：统一加锁顺序（推荐）
-- 所有事务都按 id 从小到大的顺序加锁

-- ===== 会话 A =====
BEGIN;
-- Alice id=1 < Bob id=2，先锁 Alice 再锁 Bob
UPDATE account SET balance = balance - 100 WHERE id = 1;
UPDATE account SET balance = balance + 100 WHERE id = 2;
COMMIT;

-- ===== 会话 B =====
BEGIN;
-- 同样先锁 Alice 再锁 Bob（即使 B 是 Bob 转 Alice）
UPDATE account SET balance = balance + 100 WHERE id = 1;
UPDATE account SET balance = balance - 100 WHERE id = 2;
COMMIT;

-- 方案二：乐观锁（适合低冲突场景）
BEGIN;
UPDATE account SET balance = balance - 100, version = version + 1
WHERE id = 1 AND version = 0;
-- 如果 version 不匹配，说明已被修改，重试即可
COMMIT;

-- 方案三：缩小锁范围 + 超时设置
-- 减少事务持有锁的时间
SET innodb_lock_wait_timeout = 5;  -- 等锁超时 5 秒

-- ============================================================
-- 6. 死锁监控脚本
-- ============================================================

-- 查看当前锁等待情况
SELECT
    r.trx_id AS waiting_trx,
    r.trx_mysql_thread_id AS waiting_thread,
    r.trx_query AS waiting_query,
    b.trx_id AS blocking_trx,
    b.trx_mysql_thread_id AS blocking_thread,
    b.trx_query AS blocking_query
FROM information_schema.innodb_lock_waits w
JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id
JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id;

-- MySQL 8.0+ 性能 schema 方式
SELECT * FROM performance_schema.data_lock_waits;
SELECT * FROM performance_schema.data_locks;

-- 查看死锁次数统计
SHOW STATUS LIKE 'Innodb_deadlocks';

-- ============================================================
-- 7. 清理
-- ============================================================
DROP DATABASE IF EXISTS case_deadlock;
