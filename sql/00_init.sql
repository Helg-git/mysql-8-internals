-- ============================================================
-- 00_init.sql - 基础表结构和测试数据
-- 《MySQL 原理与实战》配套仓库
-- 适用版本：MySQL 8.0.28+
-- ============================================================

-- 设置字符集
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS learn_mysql
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE learn_mysql;

-- ============================================================
-- 1. 用户表（贯穿全书的示例基础表）
-- ============================================================
DROP TABLE IF EXISTS `user`;
CREATE TABLE `user` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(50) NOT NULL COMMENT '用户名',
  `email` VARCHAR(100) NOT NULL COMMENT '邮箱',
  `phone` VARCHAR(20) DEFAULT NULL COMMENT '手机号',
  `password_hash` VARCHAR(255) NOT NULL COMMENT '密码哈希',
  `nickname` VARCHAR(50) DEFAULT NULL COMMENT '昵称',
  `avatar_url` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态：1正常 0禁用',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME DEFAULT NULL COMMENT '软删除时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_email` (`email`),
  KEY `idx_phone` (`phone`),
  KEY `idx_status_created` (`status`, `created_at`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户表';

-- ============================================================
-- 2. 商品表
-- ============================================================
DROP TABLE IF EXISTS `product`;
CREATE TABLE `product` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(200) NOT NULL COMMENT '商品名称',
  `category_id` INT UNSIGNED NOT NULL COMMENT '分类ID',
  `price` DECIMAL(10,2) NOT NULL COMMENT '价格',
  `stock` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '库存',
  `description` TEXT COMMENT '商品描述',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态：1上架 0下架',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_category_id` (`category_id`),
  KEY `idx_price` (`price`),
  KEY `idx_status` (`status`),
  KEY `idx_category_status` (`category_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='商品表';

-- ============================================================
-- 3. 商品分类表
-- ============================================================
DROP TABLE IF EXISTS `category`;
CREATE TABLE `category` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL COMMENT '分类名称',
  `parent_id` INT UNSIGNED DEFAULT NULL COMMENT '父分类ID',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='商品分类表';

-- ============================================================
-- 4. 订单表
-- ============================================================
DROP TABLE IF EXISTS `orders`;
CREATE TABLE `orders` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_no` VARCHAR(32) NOT NULL COMMENT '订单号',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `total_amount` DECIMAL(12,2) NOT NULL COMMENT '订单总金额',
  `status` TINYINT NOT NULL DEFAULT 0 COMMENT '状态：0待支付 1已支付 2已发货 3已完成 4已取消',
  `pay_time` DATETIME DEFAULT NULL COMMENT '支付时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_user_status` (`user_id`, `status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='订单表';

-- ============================================================
-- 5. 订单详情表
-- ============================================================
DROP TABLE IF EXISTS `order_item`;
CREATE TABLE `order_item` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
  `product_id` BIGINT UNSIGNED NOT NULL COMMENT '商品ID',
  `product_name` VARCHAR(200) NOT NULL COMMENT '商品名称（下单时快照）',
  `price` DECIMAL(10,2) NOT NULL COMMENT '单价',
  `quantity` INT UNSIGNED NOT NULL COMMENT '数量',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_product_id` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='订单详情表';

-- ============================================================
-- 6. 支付记录表
-- ============================================================
DROP TABLE IF EXISTS `payment`;
CREATE TABLE `payment` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
  `pay_method` TINYINT NOT NULL COMMENT '支付方式：1支付宝 2微信 3银行卡',
  `amount` DECIMAL(12,2) NOT NULL COMMENT '支付金额',
  `trade_no` VARCHAR(64) DEFAULT NULL COMMENT '第三方交易号',
  `status` TINYINT NOT NULL DEFAULT 0 COMMENT '状态：0待确认 1成功 2失败',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_trade_no` (`trade_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='支付记录表';

-- ============================================================
-- 7. 用户地址表
-- ============================================================
DROP TABLE IF EXISTS `user_address`;
CREATE TABLE `user_address` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `province` VARCHAR(50) NOT NULL COMMENT '省份',
  `city` VARCHAR(50) NOT NULL COMMENT '城市',
  `district` VARCHAR(50) NOT NULL COMMENT '区县',
  `detail` VARCHAR(200) NOT NULL COMMENT '详细地址',
  `is_default` TINYINT NOT NULL DEFAULT 0 COMMENT '是否默认地址',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户地址表';

-- ============================================================
-- 8. 操作日志表（用于演示分页、排序等场景）
-- ============================================================
DROP TABLE IF EXISTS `operation_log`;
CREATE TABLE `operation_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '操作用户ID',
  `action` VARCHAR(50) NOT NULL COMMENT '操作类型',
  `target_type` VARCHAR(50) DEFAULT NULL COMMENT '目标类型',
  `target_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '目标ID',
  `detail` TEXT COMMENT '操作详情',
  `ip` VARCHAR(45) DEFAULT NULL COMMENT 'IP地址',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_action` (`action`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_target` (`target_type`, `target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='操作日志表';

-- ============================================================
-- 9. 标签表
-- ============================================================
DROP TABLE IF EXISTS `tag`;
CREATE TABLE `tag` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL COMMENT '标签名',
  `type` VARCHAR(20) NOT NULL DEFAULT 'general' COMMENT '标签类型',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_name_type` (`name`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='标签表';

-- ============================================================
-- 10. 商品标签关联表
-- ============================================================
DROP TABLE IF EXISTS `product_tag`;
CREATE TABLE `product_tag` (
  `product_id` BIGINT UNSIGNED NOT NULL,
  `tag_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`product_id`, `tag_id`),
  KEY `idx_tag_id` (`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='商品标签关联表';

-- ============================================================
-- 插入测试数据
-- ============================================================

-- 商品分类（3 级）
INSERT INTO `category` (`id`, `name`, `parent_id`, `sort_order`) VALUES
(1, '电子产品', NULL, 1),
(2, '手机', 1, 1),
(3, '笔记本电脑', 1, 2),
(4, '配件', 1, 3),
(5, '服装', NULL, 2),
(6, '男装', 5, 1),
(7, '女装', 5, 2),
(8, '食品', NULL, 3),
(9, '零食', 8, 1),
(10, '饮料', 8, 2);

-- 标签
INSERT INTO `tag` (`id`, `name`, `type`) VALUES
(1, '热销', 'product'),
(2, '新品', 'product'),
(3, '促销', 'product'),
(4, '包邮', 'service'),
(5, '七天无理由', 'service');

-- 商品（30 条，覆盖不同分类和价格区间）
INSERT INTO `product` (`id`, `name`, `category_id`, `price`, `stock`, `description`, `status`) VALUES
(1, 'iPhone 15 Pro Max', 2, 9999.00, 500, 'Apple 最新旗舰手机', 1),
(2, 'Samsung Galaxy S24 Ultra', 2, 8999.00, 300, '三星旗舰手机', 1),
(3, '华为 Mate 60 Pro', 2, 6999.00, 200, '华为旗舰手机', 1),
(4, '小米 14 Pro', 2, 4999.00, 1000, '小米旗舰手机', 1),
(5, 'MacBook Pro 16', 3, 19999.00, 150, 'Apple 专业笔记本', 1),
(6, 'ThinkPad X1 Carbon', 3, 12999.00, 200, '联想商务笔记本', 1),
(7, 'Dell XPS 15', 3, 11999.00, 180, 'Dell 高端笔记本', 1),
(8, 'AirPods Pro 2', 4, 1899.00, 2000, 'Apple 降噪耳机', 1),
(9, 'iPhone 保护壳', 4, 99.00, 5000, '透明硅胶保护壳', 1),
(10, 'USB-C 充电线', 4, 49.00, 10000, '1.5m 快充数据线', 1),
(11, '纯棉T恤 男款', 6, 129.00, 3000, '100%纯棉 圆领', 1),
(12, '商务衬衫 男款', 6, 299.00, 1500, '免烫面料', 1),
(13, '牛仔裤 男款', 6, 399.00, 2000, '直筒修身', 1),
(14, '连衣裙', 7, 259.00, 2500, '碎花印花 雪纺', 1),
(15, '羽绒服 女款', 7, 899.00, 800, '90%白鹅绒', 1),
(16, '乐事薯片 原味', 9, 9.90, 50000, '104g 袋装', 1),
(17, '三只松鼠坚果礼盒', 9, 89.00, 5000, '混合坚果 750g', 1),
(18, '可口可乐 330ml×24', 10, 59.00, 8000, '罐装整箱', 1),
(19, '农夫山泉 550ml×24', 10, 29.00, 10000, '矿泉水整箱', 1),
(20, 'OPPO Find X7', 2, 4299.00, 600, 'OPPO 旗舰手机', 1),
(21, 'vivo X100 Pro', 2, 4599.00, 550, 'vivo 旗舰手机', 1),
(22, '一加 12', 2, 3999.00, 700, '一加旗舰手机', 1),
(23, 'Sony WH-1000XM5', 4, 2299.00, 400, 'Sony 降噪耳机', 1),
(24, '机械键盘', 4, 399.00, 3000, '87键 茶轴', 1),
(25, '运动裤 男款', 6, 199.00, 4000, '速干面料', 1),
(26, '卫衣 女款', 7, 199.00, 3500, '加绒 圆领', 1),
(27, '百草味零食大礼包', 9, 69.00, 6000, '混合零食 1kg', 1),
(28, '红牛 250ml×24', 10, 119.00, 4000, '功能饮料整箱', 1),
(29, 'iPad Air', 2, 4799.00, 350, 'Apple 平板电脑', 1),
(30, 'Surface Pro 9', 3, 8999.00, 250, '微软平板笔记本', 1);

-- 商品标签关联
INSERT INTO `product_tag` (`product_id`, `tag_id`) VALUES
(1, 1), (1, 2), (3, 1), (3, 2), (4, 3),
(8, 1), (9, 3), (10, 3), (11, 3), (12, 1),
(16, 1), (17, 2), (20, 2), (21, 3), (22, 3);

-- 用户（100 条）
INSERT INTO `user` (`username`, `email`, `phone`, `password_hash`, `nickname`, `status`, `created_at`) VALUES
-- 批量生成 100 个用户（此处列出前 10 条示例，完整数据用存储过程生成）
('user_001', 'user001@example.com', '13800000001', '$2b$10$xxxxxxxx', '小明', 1, '2024-01-15 10:30:00'),
('user_002', 'user002@example.com', '13800000002', '$2b$10$xxxxxxxx', '小红', 1, '2024-01-16 14:20:00'),
('user_003', 'user003@example.com', '13800000003', '$2b$10$xxxxxxxx', '张三', 1, '2024-01-18 09:15:00'),
('user_004', 'user004@example.com', '13800000004', '$2b$10$xxxxxxxx', '李四', 1, '2024-01-20 16:45:00'),
('user_005', 'user005@example.com', '13800000005', '$2b$10$xxxxxxxx', '王五', 1, '2024-01-22 11:00:00'),
('user_006', 'user006@example.com', '13800000006', '$2b$10$xxxxxxxx', '赵六', 1, '2024-02-01 08:30:00'),
('user_007', 'user007@example.com', '13800000007', '$2b$10$xxxxxxxx', '孙七', 1, '2024-02-05 13:20:00'),
('user_008', 'user008@example.com', '13800000008', '$2b$10$xxxxxxxx', '周八', 0, '2024-02-10 17:45:00'),
('user_009', 'user009@example.com', '13800000009', '$2b$10$xxxxxxxx', '吴九', 1, '2024-02-15 10:00:00'),
('user_010', 'user010@example.com', '13800000010', '$2b$10$xxxxxxxx', '郑十', 1, '2024-02-20 15:30:00');

-- 批量生成剩余 90 个用户
DELIMITER //
CREATE PROCEDURE generate_users()
BEGIN
  DECLARE i INT DEFAULT 11;
  WHILE i <= 100 DO
    INSERT INTO `user` (`username`, `email`, `phone`, `password_hash`, `nickname`, `status`, `created_at`)
    VALUES (
      CONCAT('user_', LPAD(i, 3, '0')),
      CONCAT('user', i, '@example.com'),
      CONCAT('1380000', LPAD(i, 5, '0')),
      '$2b$10$xxxxxxxx',
      CONCAT('用户', i),
      IF(i % 15 = 0, 0, 1),
      DATE_ADD('2024-01-01 00:00:00', INTERVAL FLOOR(RAND() * 365) DAY)
    );
    SET i = i + 1;
  END WHILE;
END //
DELIMITER ;

CALL generate_users();
DROP PROCEDURE IF EXISTS generate_users;

-- 用户地址（每个用户 1-3 个地址）
DELIMITER //
CREATE PROCEDURE generate_addresses()
BEGIN
  DECLARE i INT DEFAULT 1;
  DECLARE addr_count INT;
  WHILE i <= 100 DO
    SET addr_count = 1 + FLOOR(RAND() * 3);
    -- 第一个地址设为默认
    INSERT INTO `user_address` (`user_id`, `province`, `city`, `district`, `detail`, `is_default`)
    VALUES (i, '北京市', '北京市', '朝阳区', CONCAT('朝阳路', i, '号'), 1);
    IF addr_count >= 2 THEN
      INSERT INTO `user_address` (`user_id`, `province`, `city`, `district`, `detail`, `is_default`)
      VALUES (i, '上海市', '上海市', '浦东新区', CONCAT('张江路', i, '号'), 0);
    END IF;
    IF addr_count >= 3 THEN
      INSERT INTO `user_address` (`user_id`, `province`, `city`, `district`, `detail`, `is_default`)
      VALUES (i, '广东省', '深圳市', '南山区', CONCAT('科技园路', i, '号'), 0);
    END IF;
    SET i = i + 1;
  END WHILE;
END //
DELIMITER ;

CALL generate_addresses();
DROP PROCEDURE IF EXISTS generate_addresses;

-- 订单（1000 条）
DELIMITER //
CREATE PROCEDURE generate_orders()
BEGIN
  DECLARE i INT DEFAULT 1;
  DECLARE user_id BIGINT;
  DECLARE product_id BIGINT;
  DECLARE order_status INT;
  DECLARE order_date DATETIME;
  DECLARE order_amount DECIMAL(12,2);
  
  WHILE i <= 1000 DO
    SET user_id = 1 + FLOOR(RAND() * 100);
    SET product_id = 1 + FLOOR(RAND() * 30);
    SET order_date = DATE_ADD('2024-01-01 00:00:00', INTERVAL FLOOR(RAND() * 365) DAY);
    SET order_status = CASE FLOOR(RAND() * 5)
      WHEN 0 THEN 0 WHEN 1 THEN 1 WHEN 2 THEN 2 WHEN 3 THEN 3 ELSE 4
    END;
    
    SELECT `price` INTO order_amount FROM `product` WHERE `id` = product_id;
    
    INSERT INTO `orders` (`order_no`, `user_id`, `total_amount`, `status`, `created_at`)
    VALUES (
      CONCAT('ORD', DATE_FORMAT(order_date, '%Y%m%d'), LPAD(i, 6, '0')),
      user_id,
      order_amount * (1 + FLOOR(RAND() * 3)),
      order_status,
      order_date
    );
    
    -- 订单详情
    INSERT INTO `order_item` (`order_id`, `product_id`, `product_name`, `price`, `quantity`)
    VALUES (LAST_INSERT_ID(), product_id, (SELECT `name` FROM `product` WHERE `id` = product_id), order_amount, 1 + FLOOR(RAND() * 3));
    
    IF order_status >= 1 THEN
      UPDATE `orders` SET `pay_time` = DATE_ADD(order_date, INTERVAL FLOOR(RAND() * 3600) SECOND) WHERE `id` = LAST_INSERT_ID();
    END IF;
    
    SET i = i + 1;
  END WHILE;
END //
DELIMITER ;

CALL generate_orders();
DROP PROCEDURE IF EXISTS generate_orders;

-- 操作日志（10000 条，用于分页演示）
DELIMITER //
CREATE PROCEDURE generate_logs()
BEGIN
  DECLARE i INT DEFAULT 1;
  DECLARE log_user_id BIGINT;
  DECLARE log_date DATETIME;
  DECLARE action_type VARCHAR(50);
  
  WHILE i <= 10000 DO
    SET log_user_id = IF(RAND() < 0.1, NULL, 1 + FLOOR(RAND() * 100));
    SET log_date = DATE_ADD('2024-01-01 00:00:00', INTERVAL FLOOR(RAND() * 365 * 24 * 60) MINUTE);
    SET action_type = ELT(1 + FLOOR(RAND() * 8), 'login', 'logout', 'view_product', 'add_to_cart', 'search', 'place_order', 'payment', 'review');
    
    INSERT INTO `operation_log` (`user_id`, `action`, `target_type`, `target_id`, `ip`, `created_at`)
    VALUES (
      log_user_id,
      action_type,
      ELT(1 + FLOOR(RAND() * 4), 'product', 'order', 'user', NULL),
      IF(RAND() < 0.2, NULL, 1 + FLOOR(RAND() * 30)),
      CONCAT(FLOOR(RAND() * 255), '.', FLOOR(RAND() * 255), '.', FLOOR(RAND() * 255), '.', FLOOR(RAND() * 255)),
      log_date
    );
    
    SET i = i + 1;
  END WHILE;
END //
DELIMITER ;

CALL generate_logs();
DROP PROCEDURE IF EXISTS generate_logs;

SET FOREIGN_KEY_CHECKS = 1;

-- 验证数据
SELECT '=== 数据初始化完成 ===' AS info;
SELECT CONCAT('用户: ', COUNT(*)) AS stat FROM `user`;
SELECT CONCAT('商品: ', COUNT(*)) AS stat FROM `product`;
SELECT CONCAT('订单: ', COUNT(*)) AS stat FROM `orders`;
SELECT CONCAT('操作日志: ', COUNT(*)) AS stat FROM `operation_log`;
