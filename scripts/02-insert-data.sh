#!/bin/bash

# 參數
CONTAINER_NAME=postgres
DB_NAME=postgres
DB_USER=postgres

# 更真實的表名稱與 schema
TABLE_NAME=users

# 新 users table: 常見的 user 欄位 (id, username, email, age, created_at)
SQL_CREATE_TABLE="
CREATE TABLE IF NOT EXISTS $TABLE_NAME (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    age INT CHECK (age > 0 AND age < 100),
    created_at TIMESTAMP DEFAULT NOW()
);
"

# 插入 10 筆隨機用戶資料
SQL_INSERT_DATA="
DO \$\$
BEGIN
    FOR i IN 1..10 LOOP
        INSERT INTO $TABLE_NAME (username, email, age)
        VALUES (
            'user_' || encode(gen_random_bytes(4), 'hex'),
            'user_' || encode(gen_random_bytes(4), 'hex') || '@gmail.com',
            trunc(18 + random() * 60)::int
        );
    END LOOP;
END
\$\$;
"

echo "Creating table if not exists..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "$SQL_CREATE_TABLE"

echo "Inserting 10 random users..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "$SQL_INSERT_DATA"

echo "Done!"
