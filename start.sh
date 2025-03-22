#!/bin/bash
# Create S3 bucket
aws s3api create-bucket --bucket ${S3_BUCKET_NAME} --region us-east-1

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name ${DYNAMODB_TABLE_NAME} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
