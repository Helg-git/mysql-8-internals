-- ============================================================
-- 案例 30: 热点行并发（库存扣减）
-- 对应章节: 第 25 章 锁机制
-- MySQL 版本: 8.0+
-- 说明: 模拟高并发库存扣减场景，对比乐观锁/悲观锁/Redis 预扣减
-- ============================================================

-- 1. 准备环境
DROP DATABASE IF EXISTS case_hot_row;
CREATE DATABASE case_hot_row;
USE case_hot_row;

-- 2. 创建表结构
CREATE TABLE product (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    version INT NOT NULL DEFAULT 0,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_stock (stock)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE order_record (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    product_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    status TINYINT NOT NULL DEFAULT 0 COMMENT '0-待支付 1-已支付 2-已取消',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_product (product_id),
    KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 插入测试数据：iPhone 16 Pro，库存 100 件
INSERT INTO product (name, stock, price) VALUES
('iPhone 16 Pro', 100, 7999.00),
('MacBook Pro M4', 50, 14999.00);

SELECT * FROM product;

-- ============================================================
-- 3. 方案对比：悲观锁（FOR UPDATE）
-- ============================================================

-- 模拟用户 A 扣减库存
BEGIN;
-- 锁定商品行，防止其他事务同时修改
SELECT stock FROM product WHERE id = 1 FOR UPDATE;
-- 返回 stock = 100

-- 检查库存是否充足
-- 假设用户购买 1 件
UPDATE product SET stock = stock - 1 WHERE id = 1 AND stock >= 1;

-- 创建订单
INSERT INTO order_record (product_id, user_id, quantity, price, status)
VALUES (1, 1001, 1, 7999.00, 0);

COMMIT;

-- 验证
SELECT * FROM product WHERE id = 1;
-- stock = 99

-- ===== 悲观锁的问题 =====
-- 会话 B 同时尝试：
-- BEGIN;
-- SELECT stock FROM product WHERE id = 1 FOR UPDATE;
-- ↑ 会被阻塞，直到会话 A COMMIT
-- 高并发下所有事务排队等锁，吞吐量低

-- ============================================================
-- 4. 方案对比：乐观锁（version）
-- ============================================================

-- 重置库存
UPDATE product SET stock = 100, version = 0 WHERE id = 1;

-- 模拟并发扣减（用存储过程模拟）
DELIMITER //
CREATE PROCEDURE deduct_stock_optimistic(
    IN p_user_id BIGINT,
    IN p_quantity INT,
    OUT p_result VARCHAR(50)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_version INT;
    DECLARE v_affected INT;
    
    -- 读取当前库存和版本号
    SELECT stock, version INTO v_stock, v_version
    FROM product WHERE id = 1;
    
    -- 检查库存
    IF v_stock < p_quantity THEN
        SET p_result = 'INSUFFICIENT_STOCK';
    ELSE
        -- CAS 更新：版本号匹配才更新
        UPDATE product
        SET stock = stock - p_quantity,
            version = version + 1
        WHERE id = 1 AND version = v_version;
        
        SET v_affected = ROW_COUNT();
        
        IF v_affected = 1 THEN
            -- 创建订单
            INSERT INTO order_record (product_id, user_id, quantity, price, status)
            VALUES (1, p_user_id, p_quantity, 7999.00, 0);
            SET p_result = 'SUCCESS';
        ELSE
            -- 版本冲突，需要重试
            SET p_result = 'VERSION_CONFLICT_RETRY';
        END IF;
    END IF;
END //
DELIMITER ;

-- 测试乐观锁
CALL deduct_stock_optimistic(2001, 1, @result);
SELECT @result;
SELECT * FROM product WHERE id = 1;

-- 模拟高并发冲突（快速连续调用）
-- 在实际应用中，乐观锁冲突时应该重试 3-5 次

-- ============================================================
-- 5. 方案对比：UPDATE 条件判断（无锁）
-- ============================================================

-- 重置库存
UPDATE product SET stock = 100, version = 0 WHERE id = 1;

-- 直接用 UPDATE 的 WHERE 条件保证原子性
-- 不需要 SELECT，不需要锁，不需要版本号
UPDATE product
SET stock = stock - 1
WHERE id = 1 AND stock >= 1;

-- 检查是否成功
SELECT ROW_COUNT() AS affected_rows;
-- affected_rows = 1 表示成功
-- affected_rows = 0 表示库存不足（被其他事务抢先了）

-- 成功则创建订单
-- INSERT INTO order_record ...

-- 这个方案最简单且高效！

-- ============================================================
-- 6. 性能对比（EXPLAIN 分析）
-- ============================================================

-- 悲观锁：FOR UPDATE
EXPLAIN SELECT * FROM product WHERE id = 1 FOR UPDATE;
-- type: const, 额外开销：行级排他锁

-- 乐观锁：版本号
EXPLAIN UPDATE product SET stock = stock - 1, version = version + 1
WHERE id = 1 AND version = 0;
-- type: range (主键查找)

-- 无锁方案：条件更新
EXPLAIN UPDATE product SET stock = stock - 1
WHERE id = 1 AND stock >= 1;
-- type: range (主键查找)，最简洁

-- ============================================================
-- 7. 生产建议
-- ============================================================

-- 方案选型：
-- 1. 简单扣减 → UPDATE WHERE stock >= quantity（最推荐）
-- 2. 需要读后写逻辑 → 乐观锁（version）
-- 3. 需要绝对一致性 → 悲观锁（FOR UPDATE）
-- 4. 超高并发 → Redis 预扣减 + MQ 异步落库

-- 防超卖终极方案：库存冗余到 Redis
-- SET product:1:stock 100
-- DECR product:1:stock → 返回 >= 0 才允许下单
-- 定时同步 MySQL ← Redis

-- ============================================================
-- 8. 清理
-- ============================================================
DROP PROCEDURE IF EXISTS deduct_stock_optimistic;
DROP DATABASE IF EXISTS case_hot_row;
