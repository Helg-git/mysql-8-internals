-- ============================================================
-- 案例 09: UUID vs 自增主键性能对比
-- 对应章节: 第 9 章 - 索引使用策略 + 第 10 章 - 聚簇索引与回表
-- MySQL 版本: 8.0+
-- ============================================================
-- 本案例演示:
--   1. UUID 主键导致 B+ 树页分裂和随机 I/O
--   2. 自增主键的顺序插入优势
--   3. 插入性能对比
--   4. 索引空间占用对比
-- ============================================================

-- 1. 准备环境
CREATE DATABASE IF NOT EXISTS learn_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE learn_mysql;

-- 2. 创建表结构

-- 2.1 UUID 主键表
DROP TABLE IF EXISTS orders_uuid;
CREATE TABLE orders_uuid (
    id CHAR(36) PRIMARY KEY COMMENT 'UUID v4 主键',
    user_id BIGINT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB COMMENT='UUID 主键订单表';

-- 2.2 自增主键表
DROP TABLE IF EXISTS orders_autoinc;
CREATE TABLE orders_autoinc (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '自增主键',
    user_id BIGINT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB COMMENT='自增主键订单表';

-- 3. 插入测试数据

-- 3.1 使用存储过程批量插入 UUID 主键数据
DELIMITER //
DROP PROCEDURE IF EXISTS sp_insert_uuid//
CREATE PROCEDURE sp_insert_uuid(IN total INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    START TRANSACTION;
    WHILE i <= total DO
        INSERT INTO orders_uuid (id, user_id, amount, status, created_at)
        VALUES (
            UUID(),
            FLOOR(1 + RAND() * 10000),
            ROUND(RAND() * 10000, 2),
            IF(RAND() > 0.3, 'paid', 'pending'),
            DATE_ADD(NOW(), INTERVAL -FLOOR(RAND() * 365) DAY)
        );
        SET i = i + 1;
        -- 每 1000 行提交一次，避免 undo log 过大
        IF i % 1000 = 0 THEN
            COMMIT;
            START TRANSACTION;
        END IF;
    END WHILE;
    COMMIT;
END //
DELIMITER ;

-- 3.2 使用存储过程批量插入自增主键数据
DELIMITER //
DROP PROCEDURE IF EXISTS sp_insert_autoinc//
CREATE PROCEDURE sp_insert_autoinc(IN total INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    START TRANSACTION;
    WHILE i <= total DO
        INSERT INTO orders_autoinc (user_id, amount, status, created_at)
        VALUES (
            FLOOR(1 + RAND() * 10000),
            ROUND(RAND() * 10000, 2),
            IF(RAND() > 0.3, 'paid', 'pending'),
            DATE_ADD(NOW(), INTERVAL -FLOOR(RAND() * 365) DAY)
        );
        SET i = i + 1;
        IF i % 1000 = 0 THEN
            COMMIT;
            START TRANSACTION;
        END IF;
    END WHILE;
    COMMIT;
END //
DELIMITER ;

-- ============================================================
-- 4. 问题 SQL（有性能问题）
-- ============================================================

-- 4.1 【问题】使用 UUID 作为主键 —— 会导致 B+ 树频繁页分裂
-- UUID v4 是随机的，插入时无法利用 InnoDB 聚簇索引的顺序存储特性
-- 每次插入都可能需要分裂 B+ 树的叶子页
-- 建议先插入少量数据测试，再决定是否插入全部 10000 行

-- 插入 10000 行 UUID 数据（可能需要几秒到十几秒）
-- SET profiling = 1;
-- CALL sp_insert_uuid(10000);

-- 4.2 【问题】UUID 主键占用更多存储空间
-- CHAR(36) vs BIGINT: 36 字节 vs 8 字节
-- 主键增大 → 所有二级索引的叶子节点也要存主键 → 索引空间膨胀

-- 4.3 【问题】UUID 主键导致二级索引查找效率降低
-- 二级索引 → 回表时需要比较更长的主键值
-- 每个二级索引页能存放的条目更少 → 树更高 → I/O 更多

-- ============================================================
-- 5. 优化 SQL（正确写法）
-- ============================================================

-- 5.1 【推荐】使用自增 BIGINT 作为主键
-- 自增主键保证插入顺序与 B+ 树顺序一致
-- 新数据追加到 B+ 树末尾，不会触发页分裂
CALL sp_insert_autoinc(10000);

-- 5.2 【替代方案】如果业务必须用 UUID，使用 BINARY(16) 代替 CHAR(36)
-- BINARY(16) 存储 UUID，比 CHAR(36) 节省 56% 空间
DROP TABLE IF EXISTS orders_uuid_binary;
CREATE TABLE orders_uuid_binary (
    id BINARY(16) PRIMARY KEY COMMENT 'UUID v4 以二进制存储',
    user_id BIGINT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='UUID 二进制主键（优化版）';

-- 插入时使用 UUID_TO_BIN 转换（MySQL 8.0+）
INSERT INTO orders_uuid_binary (id, user_id, amount, status, created_at)
VALUES (UUID_TO_BIN(UUID()), 1, 100.00, 'paid', NOW());

-- 查询时使用 BIN_TO_UUID 转回可读格式
SELECT BIN_TO_UUID(id) AS order_id, user_id, amount, status
FROM orders_uuid_binary;

-- 5.3 【替代方案】使用有序 UUID（UUID v7）
-- MySQL 8.0 暂不支持原生 UUID v7，但可以用时间戳前缀模拟
-- 保证插入有序性，同时保持全局唯一
-- 示例: 使用 (时间戳前缀 + 随机数) 的方式生成有序 ID

-- ============================================================
-- 6. 验证对比（EXPLAIN）
-- ============================================================

-- 6.1 对比表空间大小
-- 自增主键表通常比 UUID 主键表小 30-50%
SELECT
    TABLE_NAME,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'learn_mysql'
  AND TABLE_NAME IN ('orders_uuid', 'orders_autoinc', 'orders_uuid_binary')
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

-- 6.2 对比二级索引的页数（页越多，树越高，查询越慢）
-- 通过 information_schema.INNODB_INDEX_STATS 查看
SELECT
    TABLE_NAME,
    INDEX_NAME,
    stat_value AS leaf_pages
FROM mysql.innodb_index_stats
WHERE database_name = 'learn_mysql'
  AND table_name IN ('orders_uuid', 'orders_autoinc')
  AND stat_name = 'n_leaf_pages'
  AND index_name = 'idx_user_id';

-- 6.3 对比查询性能
-- 6.3.1 自增主键: 二级索引回表效率高（主键值小，比较快）
EXPLAIN SELECT * FROM orders_autoinc WHERE user_id = 42 ORDER BY created_at DESC LIMIT 20;

-- 6.3.2 UUID 主键: 回表时需要比较 36 字节的主键值
-- EXPLAIN SELECT * FROM orders_uuid WHERE user_id = 42 ORDER BY created_at DESC LIMIT 20;
-- 观察: key_len 更大，扫描行数可能更多

-- 6.4 对比范围查询
-- 自增主键适合范围查询
EXPLAIN SELECT * FROM orders_autoinc WHERE id BETWEEN 1000 AND 2000;

-- UUID 主键无法利用范围查询的有序性
-- EXPLAIN SELECT * FROM orders_uuid WHERE id BETWEEN '...' AND '...';

-- ============================================================
-- 7. 清理
-- ============================================================

DROP TABLE IF EXISTS orders_uuid;
DROP TABLE IF EXISTS orders_autoinc;
DROP TABLE IF EXISTS orders_uuid_binary;
DROP PROCEDURE IF EXISTS sp_insert_uuid;
DROP PROCEDURE IF EXISTS sp_insert_autoinc;
