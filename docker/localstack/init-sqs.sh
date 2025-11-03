#!/bin/bash

# Wait for LocalStack to be fully ready
echo "Waiting for LocalStack to be ready..."
sleep 5

# Create SQS queue
echo "Creating SQS queue: laravel-requests-queue"
awslocal sqs create-queue --queue-name laravel-requests-queue

# List queues to verify
echo "Available SQS queues:"
awslocal sqs list-queues

# Get queue URL
QUEUE_URL=$(awslocal sqs get-queue-url --queue-name laravel-requests-queue --query 'QueueUrl' --output text)
echo "Queue URL: $QUEUE_URL"

# Set queue attributes (optional)
awslocal sqs set-queue-attributes \
  --queue-url $QUEUE_URL \
  --attributes VisibilityTimeout=300,MessageRetentionPeriod=345600

echo "SQS setup complete!"