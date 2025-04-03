#!/bin/bash

# Define variables
KAFKA_BIN_DIR="/opt/kafka/bin"
BOOTSTRAP_SERVER="localhost:9092"
PARTITIONS=1
REPLICATION_FACTOR=1
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092
