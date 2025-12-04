#!/bin/bash
set -e

# 创建多个数据库的初始化脚本
# 这个脚本会被 PostgreSQL 的 /docker-entrypoint-initdb.d/ 目录执行

function create_database() {
    local database=$1
    echo "Creating database: $database"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE $database;
EOSQL
}

# 创建所有需要的数据库
create_database users_db
create_database products_db
create_database orders_db

echo "All databases created successfully"









