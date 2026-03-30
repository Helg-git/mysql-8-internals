<p align="center">
  <img src="https://img.shields.io/badge/MySQL-8.0%2B-4479A1?style=flat-square&logo=mysql&logoColor=white" alt="MySQL 8.0+" />
  <img src="https://img.shields.io/badge/License-MIT-9B8E82?style=flat-square" alt="MIT License" />
  <img src="https://img.shields.io/badge/InnoDB-Storage_Engine-A67B5B?style=flat-square" alt="InnoDB" />
</p>

<h1 align="center">MySQL 8.0 Internals</h1>

<p align="center">
  <strong>Companion code repository for MySQL 8.0 Internals — covering InnoDB storage engine, query optimization, transactions, and production best practices.</strong>
</p>

<p align="center">
  <a href="https://github.com/Helg-git/mysql-8-internals"><code>github.com/Helg-git/mysql-8-internals</code></a>
</p>

---

## 📦 About

This repository provides hands-on, reproducible SQL scripts and tooling for exploring MySQL 8.0 internals. It covers the InnoDB storage engine, query optimization, transaction locking, and production-grade tuning.

**What's included:**

- 🗃️ Reproducible SQL scripts (schema + test data + exercises)
- 📊 Benchmark comparison scripts
- 🔧 Tooling & configuration scripts

> 💡 All SQL scripts run directly on MySQL 8.0+. Clone, import, and start learning.

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/Helg-git/mysql-8-internals.git
cd mysql-8-internals

# 2. Create the database
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS learn_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

# 3. Import base data (10 tables, 100 users, 30 products, 1 000 orders, 10 000 log entries)
mysql -u root -p learn_mysql < sql/00_init.sql

# 4. Verify
mysql -u root -p learn_mysql -e "SHOW TABLES; SELECT COUNT(*) FROM users; SELECT COUNT(*) FROM orders;"
```

---

## 📁 Repository Structure

```
mysql-8-internals/
├── README.md                       # This file
├── LICENSE                         # MIT License
├── .gitignore
├── sql/
│   ├── 00_init.sql                 # Base schema & test data
│   ├── case-04-charset.sql         # Character set & collation comparison
│   ├── case-09-uuid-vs-autoinc.sql # UUID vs auto-increment primary key benchmark
│   ├── case-10-index-not-used.sql  # Index misuse scenarios
│   ├── case-15-six-table-join.sql  # Multi-table JOIN optimization
│   ├── case-21-deep-paging.sql     # Deep paging (seek / deferred join)
│   ├── case-28-for-update.sql      # FOR UPDATE lock range demo
│   ├── case-29-deadlock.sql        # Deadlock reproduction & diagnosis
│   └── case-30-hot-row.sql         # Hot-row concurrency (optimistic / pessimistic locking)
├── scripts/
│   ├── benchmark.sh                # Automated benchmark runner
│   ├── explain-analyzer.sh         # EXPLAIN output formatter
│   ├── slow-query-setup.sh         # Slow query log configuration
│   └── perf-schema-dashboard.sql   # performance_schema monitoring dashboard
```

---

## 📋 Case Exercises

Each `case-*.sql` file contains a complete, self-contained exercise:

| File | Topic | Content | Difficulty |
|------|-------|---------|:----------:|
| `case-04-charset.sql` | Character Sets | utf8 vs utf8mb4, collation comparison | ⭐⭐ |
| `case-09-uuid-vs-autoinc.sql` | Primary Keys | UUID vs auto-increment, B+ tree page splits | ⭐⭐⭐ |
| `case-10-index-not-used.sql` | Indexing | 7 common index-miss scenarios | ⭐⭐ |
| `case-15-six-table-join.sql` | JOINs | 6-table JOIN, NLJ vs Hash Join | ⭐⭐⭐⭐ |
| `case-21-deep-paging.sql` | Pagination | 4 deep-paging strategies compared | ⭐⭐⭐ |
| `case-28-for-update.sql` | Locking | Primary key lock vs range lock, gap locks | ⭐⭐⭐ |
| `case-29-deadlock.sql` | Deadlocks | AB-BA deadlock reproduction & resolution | ⭐⭐⭐ |
| `case-30-hot-row.sql` | Concurrency | Inventory deduction, optimistic vs pessimistic lock | ⭐⭐⭐⭐ |

---

## 🖥️ Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| MySQL | 8.0.28 | 8.0.35+ |
| bash | 4.0+ | — |
| sysbench | optional (for benchmarks) | — |
| pt-query-digest | optional (for slow-query analysis) | — |

---

## 🤝 Contributing

Issues and pull requests are welcome. For bug reports, please open a [GitHub Issue](https://github.com/Helg-git/mysql-8-internals/issues) with the MySQL version, expected vs actual behavior, and a minimal reproducible script if possible.

---

## 📄 License

[MIT](LICENSE)

---

<p align="center"><strong>中文介绍</strong></p>

## 📦 关于

本仓库提供 MySQL 8.0 内核原理的配套代码与工具脚本，涵盖 InnoDB 存储引擎、查询优化、事务锁定和生产级调优。

**仓库内容：**

- 🗃️ 可复现的 SQL 脚本（建表 + 测试数据 + 案例练习）
- 📊 Benchmark 对比脚本
- 🔧 工具配置脚本

> 💡 所有 SQL 脚本均可在 MySQL 8.0+ 环境直接运行。克隆仓库，导入数据，即可开始学习。

---

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

---

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

---

## 📋 案例练习

每个 `case-*.sql` 文件都包含完整的练习流程：

| 文件 | 主题 | 内容 | 难度 |
|------|------|------|:----:|
| `case-04-charset.sql` | 字符集 | utf8 vs utf8mb4、排序规则对比 | ⭐⭐ |
| `case-09-uuid-vs-autoinc.sql` | 主键 | UUID vs 自增主键、B+ 树页分裂 | ⭐⭐⭐ |
| `case-10-index-not-used.sql` | 索引 | 7 种索引失效场景 | ⭐⭐ |
| `case-15-six-table-join.sql` | JOIN | 6 表 JOIN、NLJ vs Hash Join | ⭐⭐⭐⭐ |
| `case-21-deep-paging.sql` | 分页 | 深分页 4 种解法性能对比 | ⭐⭐⭐ |
| `case-28-for-update.sql` | 锁定 | 主键锁定 vs 范围锁定、间隙锁 | ⭐⭐⭐ |
| `case-29-deadlock.sql` | 死锁 | AB-BA 死锁复现、排查与解决 | ⭐⭐⭐ |
| `case-30-hot-row.sql` | 并发 | 库存扣减、乐观锁/悲观锁对比 | ⭐⭐⭐⭐ |

---

## 🖥️ 环境要求

| 组件 | 最低版本 | 推荐版本 |
|------|---------|---------|
| MySQL | 8.0.28 | 8.0.35+ |
| bash | 4.0+ | — |
| sysbench | 可选（用于 Benchmark） | — |
| pt-query-digest | 可选（用于慢查询分析） | — |

---

## 🤝 参与贡献

欢迎提交 Issue 和 Pull Request。如需反馈问题，请在 [GitHub Issues](https://github.com/Helg-git/mysql-8-internals/issues) 中附上 MySQL 版本、预期与实际行为，以及最小可复现脚本。

---

## 📄 License

[MIT](LICENSE)
