#!/bin/bash
# Delete S3 bucket
aws s3 rb s3://${S3_BUCKET_NAME} --force

# Delete DynamoDB table for locking
aws dynamodb delete-table --table-name ${DYNAMODB_TABLE_NAME} --region us-east-1
