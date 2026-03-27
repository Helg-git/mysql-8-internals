-- ============================================================
-- 案例 15: 6 表 JOIN 优化
-- 对应章节: 第 15 章 - 连接查询原理——JOIN 的底层执行方式
-- MySQL 版本: 8.0+
-- ============================================================
-- 本案例演示:
--   1. 员工-部门-薪资-项目-工时-客户 6 表关联查询
--   2. 嵌套循环连接 (NLJ) 的执行过程
--   3. Hash Join（MySQL 8.0+）的触发条件
--   4. 子查询改写为 JOIN 的优化
-- ============================================================

-- 1. 准备环境
CREATE DATABASE IF NOT EXISTS learn_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE learn_mysql;

-- 2. 创建表结构

-- 2.1 部门表
DROP TABLE IF EXISTS departments;
CREATE TABLE departments (
    dept_id INT PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(50) NOT NULL COMMENT '部门名称',
    manager_id BIGINT COMMENT '部门经理 ID',
    budget DECIMAL(15,2) COMMENT '部门预算',
    INDEX idx_dept_name (dept_name)
) ENGINE=InnoDB;

-- 2.2 员工表
DROP TABLE IF EXISTS emp;
CREATE TABLE emp (
    emp_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    emp_name VARCHAR(50) NOT NULL COMMENT '姓名',
    dept_id INT NOT NULL COMMENT '所属部门',
    hire_date DATE NOT NULL COMMENT '入职日期',
    email VARCHAR(100),
    INDEX idx_dept_id (dept_id),
    INDEX idx_emp_name (emp_name)
) ENGINE=InnoDB;

-- 2.3 薪资记录表
DROP TABLE IF EXISTS salary_records;
CREATE TABLE salary_records (
    record_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    emp_id BIGINT NOT NULL COMMENT '员工 ID',
    pay_month VARCHAR(7) NOT NULL COMMENT '薪资月份 (YYYY-MM)',
    base_salary DECIMAL(12,2) NOT NULL COMMENT '基本工资',
    bonus DECIMAL(12,2) DEFAULT 0 COMMENT '奖金',
    total_salary DECIMAL(12,2) GENERATED ALWAYS AS (base_salary + bonus) STORED,
    INDEX idx_emp_month (emp_id, pay_month),
    INDEX idx_pay_month (pay_month)
) ENGINE=InnoDB;

-- 2.4 项目表
DROP TABLE IF EXISTS projects;
CREATE TABLE projects (
    project_id INT PRIMARY KEY AUTO_INCREMENT,
    project_name VARCHAR(100) NOT NULL COMMENT '项目名称',
    customer_id INT NOT NULL COMMENT '客户 ID',
    status VARCHAR(20) NOT NULL DEFAULT 'active' COMMENT '项目状态',
    budget DECIMAL(15,2) COMMENT '项目预算',
    start_date DATE,
    end_date DATE,
    INDEX idx_customer_id (customer_id),
    INDEX idx_status (status)
) ENGINE=InnoDB;

-- 2.5 工时记录表
DROP TABLE IF EXISTS work_hours;
CREATE TABLE work_hours (
    log_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    emp_id BIGINT NOT NULL COMMENT '员工 ID',
    project_id INT NOT NULL COMMENT '项目 ID',
    work_date DATE NOT NULL COMMENT '工作日期',
    hours DECIMAL(4,1) NOT NULL COMMENT '工时',
    description VARCHAR(200) COMMENT '工作描述',
    INDEX idx_emp_project (emp_id, project_id),
    INDEX idx_work_date (work_date)
) ENGINE=InnoDB;

-- 2.6 客户表
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    company_name VARCHAR(100) NOT NULL COMMENT '公司名称',
    contact_name VARCHAR(50) COMMENT '联系人',
    industry VARCHAR(50) COMMENT '行业',
    city VARCHAR(50) COMMENT '城市',
    INDEX idx_city (city),
    INDEX idx_industry (industry)
) ENGINE=InnoDB;

-- 3. 插入测试数据

-- 3.1 部门数据
INSERT INTO departments (dept_name, manager_id, budget) VALUES
('工程部', 1, 5000000),
('产品部', 2, 3000000),
('设计部', 3, 2000000),
('市场部', 4, 2500000),
('运营部', 5, 1500000),
('财务部', 6, 1000000),
('人事部', 7, 800000),
('法务部', 8, 600000);

-- 3.2 客户数据
INSERT INTO customers (company_name, contact_name, industry, city) VALUES
('星辰科技', '王总', '互联网', '北京'),
('蓝海数据', '李总', '大数据', '上海'),
('云端智能', '张总', '人工智能', '深圳'),
('绿色能源', '赵总', '新能源', '广州'),
('金桥教育', '钱总', '教育', '杭州'),
('天宇物流', '孙总', '物流', '成都'),
('锦绣传媒', '周总', '传媒', '北京'),
('盛世金融', '吴总', '金融', '上海'),
('创新医疗', '郑总', '医疗', '广州'),
('长城通信', '冯总', '通信', '深圳');

-- 3.3 员工数据（50 人）
INSERT INTO emp (emp_name, dept_id, hire_date, email) VALUES
('张伟', 1, '2019-03-15', 'zhangwei@example.com'),
('李娜', 1, '2020-06-01', 'lina@example.com'),
('王磊', 1, '2018-01-10', 'wanglei@example.com'),
('刘洋', 2, '2021-03-20', 'liuyang@example.com'),
('陈明', 2, '2019-09-05', 'chenming@example.com'),
('杨静', 3, '2020-11-15', 'yangjing@example.com'),
('赵丽', 3, '2022-01-08', 'zhaoli@example.com'),
('黄鑫', 4, '2018-07-20', 'huangxin@example.com'),
('周杰', 4, '2021-08-10', 'zhoujie@example.com'),
('吴敏', 5, '2019-05-25', 'wumin@example.com'),
('徐强', 1, '2020-02-14', 'xuqiang@example.com'),
('孙丽', 1, '2021-12-01', 'sunli@example.com'),
('马超', 2, '2017-06-18', 'machao@example.com'),
('朱红', 3, '2019-10-22', 'zhuhong@example.com'),
('胡波', 4, '2020-04-30', 'hubo@example.com'),
('郭静', 5, '2022-03-15', 'guojing@example.com'),
('林涛', 6, '2018-09-12', 'lintao@example.com'),
('何雪', 7, '2020-07-08', 'hexue@example.com'),
('高峰', 1, '2019-11-20', 'gaofeng@example.com'),
('罗琳', 2, '2021-05-15', 'luolin@example.com'),
('谢军', 1, '2018-03-01', 'xiejun@example.com'),
('韩冰', 3, '2020-09-18', 'hanbing@example.com'),
('唐宁', 4, '2019-01-25', 'tangning@example.com'),
('蒋文', 5, '2021-07-30', 'jiangwen@example.com'),
('董亮', 1, '2020-12-10', 'dongliang@example.com'),
('宋雅', 6, '2019-04-15', 'songya@example.com'),
('于洋', 7, '2022-02-20', 'yuyang@example.com'),
('范伟', 1, '2018-08-05', 'fanwei@example.com'),
('方圆', 2, '2020-10-12', 'fangyuan@example.com'),
('石磊', 3, '2021-09-08', 'shilei@example.com'),
('任飞', 4, '2019-06-22', 'renfei@example.com'),
('袁莉', 5, '2020-01-15', 'yuanli@example.com'),
('邹勇', 1, '2017-11-30', 'zouyong@example.com'),
('邓辉', 1, '2019-08-18', 'denghui@example.com'),
('彭超', 2, '2021-02-28', 'pengchao@example.com'),
('苏洁', 3, '2020-05-10', 'sujie@example.com'),
('卢军', 4, '2018-12-05', 'lujun@example.com'),
('蔡明', 5, '2022-01-18', 'caiming@example.com'),
('田芳', 6, '2019-03-28', 'tianfang@example.com'),
('段伟', 7, '2020-08-22', 'duanwei@example.com'),
('侯鑫', 1, '2021-04-05', 'houxin@example.com'),
('邵敏', 1, '2018-05-15', 'shaomin@example.com'),
('雷刚', 2, '2020-06-30', 'leigang@example.com'),
('贺兰', 3, '2019-07-12', 'helan@example.com'),
('龙飞', 4, '2021-11-25', 'longfei@example.com'),
('万芳', 5, '2020-03-08', 'wanfang@example.com'),
('顾磊', 6, '2018-10-20', 'gulei@example.com'),
('毛军', 7, '2021-06-15', 'maojun@example.com'),
('秦华', 1, '2019-12-01', 'qinhua@example.com');

-- 3.4 薪资记录（每人最近 6 个月）
INSERT INTO salary_records (emp_id, pay_month, base_salary, bonus)
SELECT emp_id, pay_month,
       ROUND(10000 + RAND() * 35000, 2),
       ROUND(RAND() * 8000, 2)
FROM emp
CROSS JOIN (
    SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL n MONTH), '%Y-%m') AS pay_month
    FROM (SELECT 0 AS n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) t
) months;

-- 3.5 项目数据
INSERT INTO projects (project_name, customer_id, status, budget, start_date, end_date) VALUES
('智能客服系统', 1, 'active', 500000, '2024-01-15', '2024-12-31'),
('数据中台建设', 2, 'active', 800000, '2024-02-01', '2025-06-30'),
('AI 推荐引擎', 3, 'active', 600000, '2024-03-10', '2024-11-30'),
('碳排放监控', 4, 'completed', 300000, '2023-06-01', '2024-01-31'),
('在线教育平台', 5, 'active', 450000, '2024-04-01', '2025-03-31'),
('物流调度系统', 6, 'active', 350000, '2024-05-15', '2024-12-15'),
('内容管理系统', 7, 'completed', 200000, '2023-09-01', '2024-03-31'),
('风控模型平台', 8, 'active', 700000, '2024-01-01', '2025-01-31'),
('远程诊疗系统', 9, 'active', 550000, '2024-06-01', '2025-05-31'),
('5G 网络优化', 10, 'planning', 400000, '2025-01-01', '2025-12-31');

-- 3.6 工时记录（随机分配）
INSERT INTO work_hours (emp_id, project_id, work_date, hours, description)
SELECT
    e.emp_id,
    p.project_id,
    DATE_ADD('2024-01-01', INTERVAL FLOOR(RAND() * 365) DAY) AS work_date,
    ROUND(4 + RAND() * 4, 1) AS hours,
    '开发工作'
FROM emp e
CROSS JOIN projects p
WHERE RAND() > 0.7;  -- 约 30% 的员工-项目组合有工时记录

-- ============================================================
-- 4. 问题 SQL（有性能问题）
-- ============================================================

-- 4.1 【问题】使用子查询而非 JOIN —— 性能较差
-- 查询每个部门薪资最高的员工
EXPLAIN SELECT e.emp_name, d.dept_name, sr.base_salary, sr.bonus
FROM emp e
JOIN departments d ON e.dept_id = d.dept_id
JOIN salary_records sr ON e.emp_id = sr.emp_id
WHERE sr.total_salary = (
    SELECT MAX(sr2.total_salary)
    FROM salary_records sr2
    WHERE sr2.emp_id = e.emp_id
)
ORDER BY sr.total_salary DESC;

-- 4.2 【问题】6 表 JOIN 中缺少关键索引 —— 导致 Block Nested Loop
-- 注意: 去掉 work_hours 的 idx_emp_project 索引来演示
-- ALTER TABLE work_hours DROP INDEX idx_emp_project;
EXPLAIN SELECT
    e.emp_name,
    d.dept_name,
    sr.base_salary,
    sr.bonus,
    p.project_name,
    w.hours,
    c.company_name
FROM emp e
JOIN departments d ON e.dept_id = d.dept_id
JOIN salary_records sr ON e.emp_id = sr.emp_id AND sr.pay_month = '2024-06'
JOIN work_hours w ON e.emp_id = w.emp_id
JOIN projects p ON w.project_id = p.project_id
JOIN customers c ON p.customer_id = c.customer_id
WHERE d.dept_name = '工程部'
  AND p.status = 'active'
ORDER BY sr.total_salary DESC
LIMIT 20;

-- 4.3 【问题】在 JOIN 之前使用 WHERE 子查询过滤
-- 子查询执行 6 次独立的查询，效率低于一次 JOIN
EXPLAIN SELECT * FROM emp WHERE emp_id IN (
    SELECT emp_id FROM work_hours WHERE project_id IN (
        SELECT project_id FROM projects WHERE customer_id IN (
            SELECT customer_id FROM customers WHERE city = '北京'
        )
    )
);

-- ============================================================
-- 5. 优化 SQL（正确写法）
-- ============================================================

-- 5.1 【优化】使用 JOIN 替代相关子查询
-- 优化器可以更好地选择连接顺序和算法
EXPLAIN SELECT
    e.emp_name,
    d.dept_name,
    sr.base_salary,
    sr.bonus,
    sr.total_salary
FROM emp e
JOIN departments d ON e.dept_id = d.dept_id
JOIN salary_records sr ON e.emp_id = sr.emp_id
JOIN (
    SELECT emp_id, MAX(total_salary) AS max_salary
    FROM salary_records
    GROUP BY emp_id
) AS max_sal ON sr.emp_id = max_sal.emp_id AND sr.total_salary = max_sal.max_salary
ORDER BY sr.total_salary DESC;

-- 5.2 【优化】确保 JOIN 列上有索引
-- 已有索引:
--   emp.idx_dept_id → departments.dept_id
--   salary_records.idx_emp_month → emp.emp_id
--   work_hours.idx_emp_project → emp.emp_id + project_id
--   projects.idx_customer_id → customers.customer_id
EXPLAIN SELECT
    e.emp_name,
    d.dept_name,
    sr.base_salary,
    sr.bonus,
    p.project_name,
    w.hours,
    c.company_name
FROM departments d
JOIN emp e ON d.dept_id = e.dept_id
JOIN salary_records sr ON e.emp_id = sr.emp_id AND sr.pay_month = '2024-06'
JOIN work_hours w ON e.emp_id = w.emp_id
JOIN projects p ON w.project_id = p.project_id
JOIN customers c ON p.customer_id = c.customer_id
WHERE d.dept_name = '工程部'
  AND p.status = 'active'
ORDER BY sr.total_salary DESC
LIMIT 20;

-- 5.3 【优化】将嵌套子查询改写为 JOIN
EXPLAIN SELECT DISTINCT e.*
FROM emp e
JOIN work_hours w ON e.emp_id = w.emp_id
JOIN projects p ON w.project_id = p.project_id
JOIN customers c ON p.customer_id = c.customer_id
WHERE c.city = '北京';

-- 5.4 【优化】使用 STRAIGHT_JOIN 强制连接顺序（当优化器选择不正确时）
-- 一般不建议使用，仅在确认优化器选择错误时使用
-- EXPLAIN SELECT STRAIGHT_JOIN ...
--   FROM 小表 JOIN 大表 ON ...

-- 5.5 【优化】MySQL 8.0+ Hash Join 提示
-- 当连接列没有索引时，MySQL 8.0.18+ 会自动使用 Hash Join
-- 可以通过设置来观察:
SET SESSION optimizer_switch = 'block_nested_loop=on';
-- 重新执行 4.3 的查询，观察是否使用了 hash join
-- SET SESSION optimizer_switch = DEFAULT;

-- ============================================================
-- 6. 验证对比（EXPLAIN）
-- ============================================================

-- 6.1 查看 4.1 vs 5.1 的执行计划差异
-- 4.1 (相关子查询): Subquery 在 WHERE 中，对每一行都执行子查询
-- 5.1 (JOIN + 派生表): 先聚合再连接，减少重复计算

-- 6.2 查看 5.2 的执行计划
-- 理想的执行计划:
--   - departments 使用 ref/const (dept_name='工程部')
--   - emp 使用 ref (dept_id)
--   - salary_records 使用 ref (emp_id + pay_month)
--   - work_hours 使用 ref (emp_id)
--   - projects 使用 eq_ref (project_id 主键)
--   - customers 使用 eq_ref (customer_id 主键)

-- 6.3 查看连接类型
-- type 列解读:
--   eq_ref  → 主键或唯一索引，每次匹配只返回一行（最优）
--   ref     → 普通索引查找，可能返回多行
--   range   → 索引范围扫描
--   index   → 全索引扫描
--   ALL     → 全表扫描（最差）

-- 6.4 使用 EXPLAIN ANALYZE（MySQL 8.0.18+）查看实际执行时间
-- EXPLAIN ANALYZE SELECT ...;  -- 会实际执行并返回详细的执行时间和行数

-- ============================================================
-- 7. 清理
-- ============================================================

DROP TABLE IF EXISTS work_hours;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS salary_records;
DROP TABLE IF EXISTS emp;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS departments;
