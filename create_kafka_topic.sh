#!/bin/bash

# Define variables
KAFKA_BIN_DIR="/opt/kafka/bin"
BOOTSTRAP_SERVER="localhost:9092"
PARTITIONS=1
REPLICATION_FACTOR=1

# Prompt user for topic name
echo -n "Enter Kafka topic name: "
read TOPIC_NAME

# Check if Kafka binary directory exists
if [ ! -d "$KAFKA_BIN_DIR" ]; then
    echo "Error: Kafka binary directory not found at $KAFKA_BIN_DIR"
    exit 1
fi

# Create the Kafka topic
$KAFKA_BIN_DIR/kafka-topics.sh \
    --create \
    --topic "$TOPIC_NAME" \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --partitions "$PARTITIONS" \
    --replication-factor "$REPLICATION_FACTOR"

# Check if the topic was created successfully
if [ $? -eq 0 ]; then
    echo "Kafka topic '$TOPIC_NAME' created successfully."
else
    echo "Failed to create Kafka topic '$TOPIC_NAME'."
    exit 1
fi

