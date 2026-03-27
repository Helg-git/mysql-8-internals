-- ============================================================
-- 案例 10: 索引失效场景大全
-- 对应章节: 第 9 章 - 索引使用策略 + 第 10 章 - 聚簇索引与回表
-- MySQL 版本: 8.0+
-- ============================================================
-- 本案例演示:
--   1. 函数导致索引失效
--   2. 隐式类型转换
--   3. OR 条件导致索引失效
--   4. 左模糊 LIKE 导致索引失效
--   5. NOT IN / != / <> 导致索引失效
--   6. 对索引列做运算
--   7. 违反最左匹配原则
--   8. 优化器估算成本放弃索引
-- ============================================================

-- 1. 准备环境
CREATE DATABASE IF NOT EXISTS learn_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE learn_mysql;

-- 2. 创建表结构

DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL COMMENT '姓名',
    age INT NOT NULL COMMENT '年龄',
    email VARCHAR(100) NOT NULL COMMENT '邮箱',
    phone VARCHAR(20) NOT NULL COMMENT '手机号（字符串类型）',
    department VARCHAR(50) NOT NULL COMMENT '部门',
    salary DECIMAL(12,2) NOT NULL COMMENT '薪资',
    hire_date DATE NOT NULL COMMENT '入职日期',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1=在职 0=离职',
    INDEX idx_name_age (name, age),
    INDEX idx_email (email),
    INDEX idx_phone (phone),
    INDEX idx_department (department),
    INDEX idx_salary (salary),
    INDEX idx_hire_date (hire_date),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='员工表';

-- 3. 插入测试数据

DELIMITER //
DROP PROCEDURE IF EXISTS sp_insert_employees//
CREATE PROCEDURE sp_insert_employees(IN total INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE dept_list VARCHAR(500) DEFAULT '工程部,产品部,设计部,市场部,运营部,财务部,人事部,法务部';
    DECLARE dept_count INT DEFAULT 8;
    DECLARE names VARCHAR(2000) DEFAULT '张伟,王芳,李娜,刘洋,陈明,杨磊,赵丽,黄鑫,周杰,吴敏,徐强,孙丽,马超,朱红,胡波,郭静,林涛,何雪,高峰,罗琳';
    START TRANSACTION;
    WHILE i <= total DO
        INSERT INTO employees (name, age, email, phone, department, salary, hire_date, status)
        VALUES (
            ELT(1 + FLOOR(RAND() * 20), '张伟','王芳','李娜','刘洋','陈明','杨磊','赵丽','黄鑫','周杰','吴敏','徐强','孙丽','马超','朱红','胡波','郭静','林涛','何雪','高峰','罗琳'),
            22 + FLOOR(RAND() * 30),
            CONCAT('user', i, '@example.com'),
            CONCAT('138', LPAD(FLOOR(RAND() * 100000000), 8, '0')),
            SUBSTRING_INDEX(SUBSTRING_INDEX(dept_list, ',', 1 + FLOOR(RAND() * dept_count)), ',', -1),
            ROUND(8000 + RAND() * 42000, 2),
            DATE_ADD(CURDATE(), INTERVAL -FLOOR(RAND() * 3650) DAY),
            IF(RAND() > 0.1, 1, 0)
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

-- 插入 50000 行测试数据
CALL sp_insert_employees(50000);

-- ============================================================
-- 4. 问题 SQL（索引失效场景）
-- ============================================================

-- 4.1 【失效】对索引列使用函数
-- 使用了 LEFT() 函数，索引 idx_name_age 无法使用
EXPLAIN SELECT * FROM employees WHERE LEFT(name, 1) = '张';

-- 4.2 【失效】对索引列做运算
-- age + 1 运算导致索引 idx_name_age 无法使用
EXPLAIN SELECT * FROM employees WHERE age + 1 = 30;

-- 4.3 【失效】隐式类型转换
-- phone 是 VARCHAR 类型，传入数字会隐式转换为字符串
-- 但如果传入的数字不带引号，MySQL 会尝试将列转为数字
EXPLAIN SELECT * FROM employees WHERE phone = 13812345678;

-- 4.4 【失效】OR 条件中有无索引列
-- status 有索引，但 name LIKE '%明%' 会导致全表扫描
-- OR 的任一分支需要全表扫描，整个查询都会退化为全表扫描
EXPLAIN SELECT * FROM employees WHERE status = 1 OR name LIKE '%明%';

-- 4.5 【失效】左模糊 LIKE
-- LIKE 以 % 开头，无法利用 B+ 树的有序性
EXPLAIN SELECT * FROM employees WHERE name LIKE '%伟';
EXPLAIN SELECT * FROM employees WHERE name LIKE '%伟%';

-- 4.6 【失效】NOT IN（在大表上）
-- NOT IN 在大表上可能导致全表扫描
EXPLAIN SELECT * FROM employees WHERE department NOT IN ('工程部', '产品部');

-- 4.7 【失效】!= / <>
EXPLAIN SELECT * FROM employees WHERE status != 0;
EXPLAIN SELECT * FROM employees WHERE department <> '工程部';

-- 4.8 【失效】违反最左匹配原则
-- 索引 idx_name_age (name, age)，直接跳过 name 查 age
EXPLAIN SELECT * FROM employees WHERE age = 30;

-- 4.9 【失效】跳过联合索引中间列
-- 索引 idx_name_age (name, age)，跳过 age 直接查 name
EXPLAIN SELECT * FROM employees WHERE name = '张伟' AND hire_date > '2023-01-01';

-- 4.10 【失效】IS NOT NULL（某些情况下）
EXPLAIN SELECT * FROM employees WHERE department IS NOT NULL;

-- ============================================================
-- 5. 优化 SQL（索引生效写法）
-- ============================================================

-- 5.1 【修复】避免对索引列使用函数 —— 改为右侧函数或范围查询
EXPLAIN SELECT * FROM employees WHERE name LIKE '张%';
-- 或使用函数索引（MySQL 8.0.13+）:
-- ALTER TABLE employees ADD INDEX idx_name_first ((LEFT(name, 1)));

-- 5.2 【修复】避免对索引列做运算 —— 将运算移到等号右侧
EXPLAIN SELECT * FROM employees WHERE age = 29;  -- age + 1 = 30 等价于 age = 29

-- 5.3 【修复】避免隐式类型转换 —— 保持类型一致
EXPLAIN SELECT * FROM employees WHERE phone = '13812345678';

-- 5.4 【修复】OR 条件改为 UNION ALL
-- 将 OR 分拆为两个查询，分别走各自的索引
EXPLAIN
SELECT * FROM employees WHERE status = 1
UNION ALL
SELECT * FROM employees WHERE name LIKE '%明%';

-- 5.5 【修复】避免左模糊 —— 使用右模糊
EXPLAIN SELECT * FROM employees WHERE name LIKE '张%';
EXPLAIN SELECT * FROM employees WHERE name LIKE '张伟%';

-- 5.6 【修复】NOT IN 改为 NOT EXISTS 或 LEFT JOIN ... IS NULL
EXPLAIN SELECT e.* FROM employees e
WHERE NOT EXISTS (
    SELECT 1 FROM (SELECT '工程部' AS dept UNION SELECT '产品部') AS tmp
    WHERE tmp.dept = e.department
);

-- 5.7 【修复】!= / <> 改为具体的 IN 或范围查询
EXPLAIN SELECT * FROM employees WHERE status = 1;  -- 如果 status 只有 0 和 1

-- 5.8 【修复】遵循最左匹配原则
EXPLAIN SELECT * FROM employees WHERE name = '张伟' AND age = 30;

-- 5.9 【修复】遵循联合索引的顺序
-- 如果需要同时按 name 和 hire_date 查询，考虑创建联合索引
ALTER TABLE employees ADD INDEX idx_name_hire (name, hire_date);
EXPLAIN SELECT * FROM employees WHERE name = '张伟' AND hire_date > '2023-01-01';

-- ============================================================
-- 6. 验证对比（EXPLAIN）
-- ============================================================

-- 对比 4.1 vs 5.1: 函数导致失效 vs 右模糊命中索引
-- 4.1: EXPLAIN SELECT * FROM employees WHERE LEFT(name, 1) = '张';
--       → type=ALL（全表扫描）
-- 5.1: EXPLAIN SELECT * FROM employees WHERE name LIKE '张%';
--       → type=range（索引范围扫描）

-- 对比 4.3 vs 5.3: 隐式转换 vs 显式类型一致
-- 4.3: EXPLAIN SELECT * FROM employees WHERE phone = 13812345678;
--       → 可能 type=ALL（隐式转换导致失效）
-- 5.3: EXPLAIN SELECT * FROM employees WHERE phone = '13812345678';
--       → type=ref（索引查找）

-- 对比 4.5 vs 5.5: 左模糊 vs 右模糊
-- 4.5: EXPLAIN SELECT * FROM employees WHERE name LIKE '%伟';
--       → type=ALL
-- 5.5: EXPLAIN SELECT * FROM employees WHERE name LIKE '张%';
--       → type=range

-- 对比 4.8 vs 5.8: 违反最左匹配 vs 遵循最左匹配
-- 4.8: EXPLAIN SELECT * FROM employees WHERE age = 30;
--       → type=ALL
-- 5.8: EXPLAIN SELECT * FROM employees WHERE name = '张伟' AND age = 30;
--       → type=ref

-- 对比 4.7 vs 5.7: != vs 具体值
-- 4.7: EXPLAIN SELECT * FROM employees WHERE status != 0;
--       → type=ALL
-- 5.7: EXPLAIN SELECT * FROM employees WHERE status = 1;
--       → type=ref

-- ============================================================
-- 7. 清理
-- ============================================================

DROP TABLE IF EXISTS employees;
DROP PROCEDURE IF EXISTS sp_insert_employees;
