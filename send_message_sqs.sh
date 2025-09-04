#!/bin/bash

set -e
AWS_REGION="us-east-1"

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

aws sqs send-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/my-job-queue \
  --message-body '{"job_id": "1", "status": "IN_PROGRESS"}'