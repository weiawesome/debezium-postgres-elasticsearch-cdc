# Capture Data Change (CDC) Postgres data to Elasticsearch

> By Debezium and Kafka Connect

<div align="center">

[📖 中文](README.zh.md) | [📖 English](README.md)

</div>

---

## 目錄

- [為什麼創建這專案](#為什麼創建這專案)
- [系統架構圖](#系統架構圖)
- [如何下載](#如何下載)
- [如何使用](#如何使用)
- [踩過的坑](#踩過的坑)

---

## 為什麼創建這專案

坦白說，很早時候就一直有 CDC 的需求。從之前做 [影片串流平台 Gimy Clone](https://github.com/weiawesome/gimy_clone_api)，想要讓用戶做查詢更加生產環境一點，那時候搭建了 Elasticsearch 來做查詢，不過當時是用雙寫的方式，完全沒處理錯誤的問題。

後續當兵時候也看蠻多書的，介紹相關概念，包含 ETL 與其他概念。

當完兵後更有趣的，我去一間公司，就是在做 CDC 並近一步包裝成一個企業級產品（當然他是用自己撰寫的程序，不是直接使用 Debezium 與 Kafka Connect）。真的是跟 CDC 很有緣分。

最近又再寫一個軟體應用，感覺又可以用到搜索引擎（這回可以加入 CDC 技術了吧 哈哈哈）。

[網路直播平台 Wes IO Live](https://github.com/weiawesome/wes-io-live) 這回當然來嘗試嘗試最知名的 Debezium 與 Kafka Connect 來做 CDC。

---

## 系統架構圖

![系統架構圖](./assets/architecture.png)

---

## 如何下載

### 1. 下載專案

```bash
git clone https://github.com/weiawesome/debezium-postgres-elasticsearch-cdc.git
```

### 2. 進入專案目錄

```bash
cd debezium-postgres-elasticsearch-cdc
```

---

## 如何使用

### 階段一：環境準備

#### 步驟 1：啟動基礎服務

使用 `docker-compose` 啟動 postgres、elasticsearch、kafka：

```bash
docker-compose up -d postgres elasticsearch kafka
```

#### 步驟 2：Postgres 新增表與插入資料

```bash
# 使用腳本（腳本細節：使用 docker exec 執行 psql 命令）
bash ./scripts/02-insert-data.sh
```

---

### 階段二：Postgres → Kafka (Debezium CDC)

#### 步驟 3：建立 connect-debezium 所需的 topics

對應 `docker-compose.yaml` 中 connect-debezium 容器的環境變數設定值：

```bash
docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 \
  --create --topic connect-configs-debezium \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact

docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 \
  --create --topic connect-offsets-debezium \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact

docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 \
  --create --topic connect-status-debezium \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact
```

#### 步驟 4：啟動 connect-debezium

```bash
docker-compose up -d connect-debezium
```

#### 步驟 5：新增 connector（Postgres → Kafka）

```bash
curl -X POST -H "Content-Type: application/json" http://localhost:8083/connectors -d @./configs/connector.json
```

#### 步驟 6：檢查 connector 狀態

```bash
# 檢查 connector 數量
curl http://localhost:8083/connectors | jq

# 檢查 connector 狀態
curl http://localhost:8083/connectors/cdc-connector | jq

# 檢查 connector 狀態（含詳細資訊）
curl http://localhost:8083/connectors/cdc-connector/status | jq
```

#### 步驟 7：驗證 Kafka 資料

```bash
# 檢查 topics 數量
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list

# 消費 Kafka 中的資料
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic cdc-public-users --from-beginning
# 可透過 ctrl + c 停止消費，查看消費數量
```

#### 步驟 8：插入新資料並驗證 CDC 是否運作

```bash
# 插入新資料
bash ./scripts/02-insert-data.sh

# 檢查 topics 數量
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list

# 消費 Kafka 中的資料（正常下會看到新插入的資料）
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic cdc-public-users --from-beginning
# 可透過 ctrl + c 停止消費，查看消費數量
```

---

### 階段三：Kafka → Elasticsearch

#### 步驟 9：建立 connect-kafka-es 所需的 topics

對應 `docker-compose.yaml` 中 connect-kafka-es 容器的環境變數設定值：

```bash
docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 \
  --create --topic connect-configs-kafka-es \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact

docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 \
  --create --topic connect-offsets-kafka-es \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact

docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 \
  --create --topic connect-status-kafka-es \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact
```

#### 步驟 10：啟動 connect-kafka-es

```bash
docker-compose up -d connect-kafka-es
```

#### 步驟 11：建立 DLQ topic

對應 `./configs/sink.json` 中的 `errors.deadletterqueue.topic.name` 設定值：

```bash
docker exec -it kafka kafka-topics --bootstrap-server kafka:9092 \
  --create --topic dlq-elasticsearch \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact
```

#### 步驟 12：新增 connector（Kafka → Elasticsearch）

```bash
curl -X POST -H "Content-Type: application/json" http://localhost:8085/connectors -d @./configs/sink.json
```

#### 步驟 13：檢查 connector 狀態

```bash
# 檢查 connector 數量
curl http://localhost:8085/connectors | jq

# 檢查 connector 狀態
curl http://localhost:8085/connectors/postgres-es-sink | jq

# 檢查 connector 狀態（含詳細資訊）
curl http://localhost:8085/connectors/postgres-es-sink/status | jq
```

#### 步驟 14：檢查 Elasticsearch 資料

```bash
curl "http://localhost:9200/cdc-public-users/_search" | jq
```

#### 步驟 15：插入新資料並驗證端對端同步

```bash
# 插入新資料
bash ./scripts/02-insert-data.sh

# 檢查 Elasticsearch 資料數量（正常下會看到新插入的資料）
curl "http://localhost:9200/cdc-public-users/_search" | jq
```

---

## 踩過的坑

> 痛得要死

[Elasticsearch Sink Connector](https://docs.confluent.io/kafka-connectors/elasticsearch/current/overview.html) 後面才仔細看到，文檔只有說明支援 v7、v8 版本，沒提到 v9 版本。一直出錯誤，然後我還不知從哪裡改起好，最後最後才意外發現版本不合，差點吐血。
