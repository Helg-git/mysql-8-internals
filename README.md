# MySQL 8.0 内核原理与实战

> 配套代码仓库 | MySQL 8.0+

## 📦 仓库说明

本仓库是掘金小册《MySQL 原理与实战：从底层到生产级调优》的配套代码仓库，包含：
- 🗃️ 可复现的 SQL 脚本（建表 + 测试数据 + 案例练习）
- 📊 Benchmark 对比脚本
- 🔧 工具配置脚本

> 💡 **所有 SQL 脚本均可在 MySQL 8.0+ 环境直接运行，无需购买专栏即可使用。**

## 🚀 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/Helg-git/mysql-8-internals.git
cd mysql-8-internals

# 2. 创建数据库
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS learn_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

# 3. 导入基础数据（10 张表、100 用户、30 商品、1000 订单、10000 日志）
mysql -u root -p learn_mysql < sql/00_init.sql

# 4. 验证
mysql -u root -p learn_mysql -e "SHOW TABLES; SELECT COUNT(*) FROM users; SELECT COUNT(*) FROM orders;"
```

## 📁 仓库结构

```
mysql-8-internals/
├── README.md                       # 本文件
├── LICENSE                         # MIT 开源协议
├── .gitignore
├── sql/
│   ├── 00_init.sql                 # 基础表结构和测试数据
│   ├── case-04-charset.sql         # 字符集与排序规则对比实验
│   ├── case-09-uuid-vs-autoinc.sql # UUID vs 自增主键性能对比
│   ├── case-10-index-not-used.sql  # 索引失效场景大全
│   ├── case-15-six-table-join.sql  # 多表 JOIN 优化实战
│   ├── case-21-deep-paging.sql     # 深分页优化（书签法/延迟关联）
│   ├── case-28-for-update.sql      # FOR UPDATE 锁范围演示
│   ├── case-29-deadlock.sql        # 死锁复现与排查
│   └── case-30-hot-row.sql         # 热点行并发（乐观锁/悲观锁）
├── scripts/
│   ├── benchmark.sh                # Benchmark 自动化脚本
│   ├── explain-analyzer.sh         # EXPLAIN 输出格式化工具
│   ├── slow-query-setup.sh         # 慢查询配置脚本
│   └── perf-schema-dashboard.sql   # performance_schema 监控面板
```

## 📋 案例练习

每个 `case-*.sql` 文件都包含完整的练习流程：

| 文件 | 对应章节 | 内容 | 难度 |
|------|---------|------|------|
| `case-04-charset.sql` | 第 4 章 | utf8 vs utf8mb4、排序规则对比 | ⭐⭐ |
| `case-09-uuid-vs-autoinc.sql` | 第 9 章 | UUID vs 自增主键、B+ 树页分裂 | ⭐⭐⭐ |
| `case-10-index-not-used.sql` | 第 10 章 | 7 种索引失效场景 | ⭐⭐ |
| `case-15-six-table-join.sql` | 第 15 章 | 6 表 JOIN、NLJ vs Hash Join | ⭐⭐⭐⭐ |
| `case-21-deep-paging.sql` | 第 21 章 | 深分页 4 种解法性能对比 | ⭐⭐⭐ |
| `case-28-for-update.sql` | 第 25 章 | 主键锁定 vs 范围锁定、间隙锁 | ⭐⭐⭐ |
| `case-29-deadlock.sql` | 第 25 章 | AB-BA 死锁复现、排查与解决 | ⭐⭐⭐ |
| `case-30-hot-row.sql` | 第 25 章 | 库存扣减、乐观锁/悲观锁对比 | ⭐⭐⭐⭐ |

## 📋 环境要求

- MySQL 8.0.28+（推荐 8.0.35+）
- bash 4.0+
- sysbench（可选，用于 Benchmark）
- pt-query-digest（可选，用于慢查询分析）

## 🔗 相关链接

- 📖 **掘金小册主页**（即将上架）
- 🐛 问题反馈：[GitHub Issues](https://github.com/Helg-git/mysql-8-internals/issues)

## 📄 License

MIT
