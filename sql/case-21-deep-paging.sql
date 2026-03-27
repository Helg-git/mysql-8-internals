-- ============================================================
-- 案例 21: 深分页优化
-- 对应章节: 第 21 章 - 分页优化——深分页的多种解法
-- MySQL 版本: 8.0+
-- ============================================================
-- 本案例演示:
--   1. LIMIT offset 的性能问题
--   2. 书签法（Seek Method）优化
--   3. 延迟关联（Deferred Join）优化
--   4. 覆盖索引优化
-- ============================================================

-- 1. 准备环境
CREATE DATABASE IF NOT EXISTS learn_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE learn_mysql;

-- 2. 创建表结构

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL COMMENT '用户 ID',
    amount DECIMAL(12,2) NOT NULL COMMENT '订单金额',
    status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '订单状态',
    product_name VARCHAR(200) NOT NULL COMMENT '商品名称',
    address TEXT COMMENT '收货地址',
    remark VARCHAR(500) COMMENT '备注',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_user_created (user_id, created_at),
    INDEX idx_status_created (status, created_at)
) ENGINE=InnoDB COMMENT='订单表';

-- 3. 插入测试数据（100 万行）

DELIMITER //
DROP PROCEDURE IF EXISTS sp_insert_orders//
CREATE PROCEDURE sp_insert_orders(IN total INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE batch_size INT DEFAULT 5000;
    DECLARE status_list VARCHAR(200) DEFAULT 'pending,paid,shipped,completed,cancelled';
    START TRANSACTION;
    WHILE i <= total DO
        INSERT INTO orders (user_id, amount, status, product_name, address, remark, created_at)
        VALUES (
            FLOOR(1 + RAND() * 100000),
            ROUND(10 + RAND() * 9990, 2),
            SUBSTRING_INDEX(SUBSTRING_INDEX(status_list, ',', 1 + FLOOR(RAND() * 5)), ',', -1),
            CONCAT('商品-', FLOOR(1 + RAND() * 500)),
            CONCAT('地址-', FLOOR(1 + RAND() * 10000)),
            '备注信息',
            DATE_ADD(NOW(), INTERVAL -FLOOR(RAND() * 365) DAY)
        );
        SET i = i + 1;
        IF i % batch_size = 0 THEN
            COMMIT;
            START TRANSACTION;
            -- 显示进度（仅在交互式终端有效）
            -- SELECT CONCAT('已插入 ', i, ' / ', total) AS progress;
        END IF;
    END WHILE;
    COMMIT;
END //
DELIMITER ;

-- 插入 100 万行数据（约需要 30-60 秒）
SELECT '开始插入 100 万行数据...' AS status;
CALL sp_insert_orders(1000000);
SELECT '数据插入完成' AS status;

-- ============================================================
-- 4. 问题 SQL（有性能问题）
-- ============================================================

-- 4.1 【问题】经典深分页 —— LIMIT offset 极大时性能急剧下降
-- MySQL 需要扫描 offset + size 行，然后丢弃前 offset 行
-- 100 万行数据，offset = 100000，实际扫描 100010 行
-- 其中 100000 行被丢弃，只有 10 行是有用的

-- 先记录执行时间
SET profiling = 1;

-- 深分页查询（可能需要数秒）
SELECT id, user_id, amount, status, product_name, created_at
FROM orders
ORDER BY created_at DESC
LIMIT 100000, 10;

-- 查看执行时间和扫描行数
SHOW PROFILE FOR QUERY 1;

-- 4.2 【问题】SELECT * 加剧深分页问题
-- 如果 SELECT *，每行都需要回表取完整数据
-- 100 万次回表，性能灾难
-- SELECT * FROM orders ORDER BY created_at DESC LIMIT 100000, 10;

-- 4.3 【问题】COUNT(*) + LIMIT 的两次查询模式
-- 前端分页通常需要总行数和当前页数据，导致两次查询
SELECT COUNT(*) FROM orders WHERE status = 'paid';  -- 第一次查询
SELECT * FROM orders WHERE status = 'paid' ORDER BY created_at DESC LIMIT 100000, 10;  -- 第二次查询

-- ============================================================
-- 5. 优化 SQL（正确写法）
-- ============================================================

-- 5.1 【方案一：书签法（Seek Method）】—— 最推荐的深分页方案
-- 核心思想: 记住上一页最后一条记录的 ID（或排序字段值），
--          用 WHERE 条件替代 OFFSET，避免扫描大量无用行
-- 优点: 性能不受 offset 大小影响，O(1) 复杂度
-- 缺点: 只能"下一页"，不支持跳页

-- 模拟: 假设上一页最后一条记录的 created_at = '2024-03-15 10:30:00'，id = 900001
-- 获取第一页
SELECT id, user_id, amount, status, product_name, created_at
FROM orders
ORDER BY created_at DESC
LIMIT 10;

-- 假设上一页最后一条的 created_at 和 id 作为书签
SET @last_created_at = '2024-03-15 10:30:00';
SET @last_id = 900001;

-- 使用书签获取下一页（性能与第一页相同！）
SELECT id, user_id, amount, status, product_name, created_at
FROM orders
WHERE created_at < @last_created_at
   OR (created_at = @last_created_at AND id < @last_id)
ORDER BY created_at DESC, id DESC
LIMIT 10;

-- 验证: EXPLAIN 应该显示 type=range，扫描行数远小于 offset
EXPLAIN SELECT id, user_id, amount, status, product_name, created_at
FROM orders
WHERE created_at < @last_created_at
   OR (created_at = @last_created_at AND id < @last_id)
ORDER BY created_at DESC, id DESC
LIMIT 10;

-- 5.2 【方案二：延迟关联（Deferred Join）】—— 通用性最强的方案
-- 核心思想: 先通过覆盖索引快速定位需要的行的 ID，
--          再用这些 ID 去回表取完整数据
-- 优点: 通用性强，不需要前端配合
-- 缺点: 子查询仍需扫描大量索引行

-- 优化前（深分页，扫描大量行并回表）
-- SELECT * FROM orders ORDER BY created_at DESC LIMIT 100000, 10;

-- 优化后（先查 ID，再回表）
SELECT o.*
FROM orders o
INNER JOIN (
    SELECT id
    FROM orders
    ORDER BY created_at DESC
    LIMIT 100000, 10
) AS tmp ON o.id = tmp.id
ORDER BY o.created_at DESC;

-- 验证: 内层子查询只扫描索引（覆盖索引），不回表
-- 外层查询只回表 10 次
EXPLAIN SELECT o.*
FROM orders o
INNER JOIN (
    SELECT id
    FROM orders
    ORDER BY created_at DESC
    LIMIT 100000, 10
) AS tmp ON o.id = tmp.id;

-- 5.3 【方案三：覆盖索引】—— 零回表
-- 核心思想: 如果查询只需要索引中已有的列，完全不需要回表
-- 优点: 最快的方案，不需要任何回表
-- 缺点: 只适用于查询列全部在索引中的场景

-- 创建覆盖索引（包含所有需要查询的列）
ALTER TABLE orders ADD INDEX idx_covering (created_at, user_id, amount, status);

-- 使用覆盖索引查询
SELECT user_id, amount, status
FROM orders
ORDER BY created_at DESC
LIMIT 100000, 10;

-- 验证: EXPLAIN 应该显示 Using index（覆盖索引扫描）
EXPLAIN SELECT user_id, amount, status
FROM orders
ORDER BY created_at DESC
LIMIT 100000, 10;

-- 5.4 【方案四：游标分页（Cursor-based Pagination）】
-- 适用于 API 接口，使用上一页最后一条记录的主键作为游标
-- 实现示例:
-- 请求: GET /api/orders?cursor=900000&limit=10
-- 响应: { data: [...], next_cursor: 900010, has_more: true }

-- 使用 BETWEEN + 游标实现
SELECT id, user_id, amount, status, product_name, created_at
FROM orders
WHERE id > 900000
ORDER BY id ASC
LIMIT 10;

-- 验证: 使用主键范围查询，type=range，非常高效
EXPLAIN SELECT id, user_id, amount, status, product_name, created_at
FROM orders
WHERE id > 900000
ORDER BY id ASC
LIMIT 10;

-- ============================================================
-- 6. 验证对比（EXPLAIN）
-- ============================================================

-- 6.1 对比四种方案的扫描行数

-- 方案一: 书签法
EXPLAIN SELECT id, user_id, amount, status, product_name, created_at
FROM orders
WHERE created_at < '2024-03-15 10:30:00'
ORDER BY created_at DESC, id DESC
LIMIT 10;
-- 预期: rows 数量很小，type=range

-- 方案二: 延迟关联
EXPLAIN SELECT o.*
FROM orders o
INNER JOIN (
    SELECT id FROM orders ORDER BY created_at DESC LIMIT 100000, 10
) AS tmp ON o.id = tmp.id;
-- 预期: 内层 type=index（覆盖索引），外层 type=eq_ref（主键查找）

-- 方案三: 覆盖索引
EXPLAIN SELECT user_id, amount, status
FROM orders
ORDER BY created_at DESC
LIMIT 100000, 10;
-- 预期: type=index, Extra=Using index

-- 方案四: 游标分页
EXPLAIN SELECT * FROM orders WHERE id > 900000 ORDER BY id ASC LIMIT 10;
-- 预期: type=range, rows=10

-- 6.2 使用 profiling 对比实际执行时间
-- （如果前面已开启 profiling，可以直接 SHOW PROFILES 查看）

-- ============================================================
-- 7. 清理
-- ============================================================

DROP TABLE IF EXISTS orders;
DROP PROCEDURE IF EXISTS sp_insert_orders;
