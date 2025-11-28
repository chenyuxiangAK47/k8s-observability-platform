-- 这个 SQL 脚本的目的：
-- 在同一个 Postgres 实例里为每个微服务创建**独立数据库**，
-- 避免所有服务共用一个数据库，从而更贴近真实微服务“数据自治”的实践。

-- 用户服务独立数据库：只存用户相关表
CREATE DATABASE users_db;

-- 商品服务独立数据库：只存商品/库存相关表
CREATE DATABASE products_db;

-- 订单服务独立数据库：只存订单相关表
CREATE DATABASE orders_db;




