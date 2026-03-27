-- ============================================================
-- 案例 04: 字符集与排序规则
-- 对应章节: 第 4 章 - 字符集与排序规则——从"锟斤拷"到 utf8mb4
-- MySQL 版本: 8.0+
-- ============================================================
-- 本案例演示:
--   1. utf8 vs utf8mb4 的区别（emoji 存储问题）
--   2. 排序规则对比较的影响（_ci vs _bin）
--   3. 乱码复现与修复
-- ============================================================

-- 1. 准备环境
CREATE DATABASE IF NOT EXISTS learn_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE learn_mysql;

-- 2. 创建表结构

-- 2.1 使用 utf8（阉割版）的表 —— 无法存储 emoji
DROP TABLE IF EXISTS user_utf8;
CREATE TABLE user_utf8 (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    nickname VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='utf8 字符集表（阉割版，无法存 emoji）';

-- 2.2 使用 utf8mb4 的表 —— 支持全部 Unicode 字符
DROP TABLE IF EXISTS user_utf8mb4;
CREATE TABLE user_utf8mb4 (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    nickname VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='utf8mb4 字符集表（完整 UTF-8）';

-- 2.3 排序规则对比表 —— _ci（不区分大小写）vs _bin（二进制精确比较）
DROP TABLE IF EXISTS user_ci, user_bin;
CREATE TABLE user_ci (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='不区分大小写排序';

CREATE TABLE user_bin (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='二进制精确排序';

-- 2.4 乱码演示表
DROP TABLE IF EXISTS user_gbk;
CREATE TABLE user_gbk (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=gbk COMMENT='GBK 字符集表（用于乱码演示）';

-- 3. 插入测试数据

-- 3.1 基本数据
INSERT INTO user_utf8 (name, nickname) VALUES ('张三', '老张');
INSERT INTO user_utf8 (name, nickname) VALUES ('李四', '小李飞刀');
INSERT INTO user_utf8mb4 (name, nickname) VALUES ('张三', '老张');
INSERT INTO user_utf8mb4 (name, nickname) VALUES ('李四', '小李飞刀');

-- 3.2 排序规则测试数据
INSERT INTO user_ci (username) VALUES ('Alice'), ('alice'), ('ALICE'), ('Bob'), ('bob');
INSERT INTO user_bin (username) VALUES ('Alice'), ('alice'), ('ALICE'), ('Bob'), ('bob');

-- 3.3 乱码演示数据
INSERT INTO user_gbk (name) VALUES ('中文测试');

-- ============================================================
-- 4. 问题 SQL（有性能问题或容易出错）
-- ============================================================

-- 4.1 【问题】尝试向 utf8 表插入 emoji —— 会报错
-- 错误: Incorrect string value: '\xF0\x9F\x98\x82' for column 'nickname'
-- MySQL 的 utf8 最多只支持 3 字节，而 emoji 需要 4 字节（U+1F602 = 😂）
INSERT INTO user_utf8 (name, nickname) VALUES ('王五', '笑哭了😂');

-- 4.2 【问题】排序规则 _ci 导致比较不精确
-- 在 _ci 排序规则下，'Alice' = 'alice' = 'ALICE'
-- 这可能导致本应不同的用户名被视为相同
SELECT username FROM user_ci WHERE username = 'alice';
-- 预期结果: 返回 3 行（Alice, alice, ALICE）—— 这可能不是你想要的

-- 4.3 【问题】隐式字符集转换导致索引失效
-- 当连接两个不同字符集的列时，MySQL 会进行隐式转换
-- 这会导致索引无法使用
SELECT * FROM user_utf8 u1 JOIN user_utf8mb4 u2 ON u1.name = u2.name;
-- EXPLAIN 会显示 type=ALL（全表扫描），因为字符集不同

-- 4.4 【问题】GBK 与 UTF-8 混用导致乱码
-- 如果数据库连接使用 utf8mb4，但表使用 gbk，
-- 插入数据时可能出现乱码（"锟斤拷"）
SET NAMES utf8mb4;
INSERT INTO user_gbk (name) VALUES ('锟斤拷测试');

-- ============================================================
-- 5. 优化 SQL（正确写法）
-- ============================================================

-- 5.1 【正确】使用 utf8mb4 存储所有数据，包括 emoji
INSERT INTO user_utf8mb4 (name, nickname) VALUES ('王五', '笑哭了😂');
INSERT INTO user_utf8mb4 (name, nickname) VALUES ('赵六', '庆祝🎉');
INSERT INTO user_utf8mb4 (name, nickname) VALUES ('孙七', '爱心❤️');
SELECT * FROM user_utf8mb4;

-- 5.2 【正确】需要精确比较时使用 _bin 排序规则
-- _bin 排序规则下，'Alice' != 'alice'
SELECT username FROM user_bin WHERE username = 'alice';
-- 预期结果: 只返回 1 行（alice）

-- 5.3 【正确】如果需要区分大小写的比较，可以显式指定 COLLATE
-- 即使表使用 _ci 排序规则，也可以在查询时临时切换
SELECT username FROM user_ci WHERE username = 'alice' COLLATE utf8mb4_bin;
-- 预期结果: 只返回 1 行（alice）

-- 5.4 【正确】确保列和连接的字符集一致，避免隐式转换
-- 方法1: 统一使用 utf8mb4（推荐）
ALTER TABLE user_utf8 CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
-- 方法2: 在连接条件中显式指定字符集
SELECT * FROM user_utf8 u1 JOIN user_utf8mb4 u2 ON u1.name = u2.name COLLATE utf8mb4_general_ci;

-- 5.5 【正确】修复乱码 —— 先清理再重新插入
-- 确保连接字符集与表字符集一致
SET NAMES gbk;
DELETE FROM user_gbk WHERE name LIKE '%锟斤拷%';
INSERT INTO user_gbk (name) VALUES ('中文测试');
SET NAMES utf8mb4;  -- 恢复默认

-- ============================================================
-- 6. 验证对比（EXPLAIN）
-- ============================================================

-- 6.1 验证字符集一致性对索引使用的影响
-- 先加索引
ALTER TABLE user_utf8mb4 ADD INDEX idx_name (name);
ALTER TABLE user_utf8 ADD INDEX idx_name (name);

-- 字符集不同的表 JOIN —— 索引失效
EXPLAIN SELECT * FROM user_utf8 u1 JOIN user_utf8mb4 u2 ON u1.name = u2.name;
-- 观察: type 列应该显示 ALL（全表扫描）
-- Extra 列可能出现 Using where; Using join buffer

-- 6.2 验证排序规则对查询结果的影响
-- _ci 排序规则: 不区分大小写
SELECT username, HEX(username) FROM user_ci WHERE username = 'alice';
-- _bin 排序规则: 区分大小写
SELECT username, HEX(username) FROM user_bin WHERE username = 'alice';

-- 6.3 验证字符集信息
SELECT TABLE_NAME, TABLE_COLLATION, CHARACTER_SET_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'learn_mysql' AND TABLE_NAME LIKE 'user_%';

SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_SET_NAME, COLLATION_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'learn_mysql' AND TABLE_NAME LIKE 'user_%';

-- ============================================================
-- 7. 清理
-- ============================================================

DROP TABLE IF EXISTS user_utf8;
DROP TABLE IF EXISTS user_utf8mb4;
DROP TABLE IF EXISTS user_ci;
DROP TABLE IF EXISTS user_bin;
DROP TABLE IF EXISTS user_gbk;
