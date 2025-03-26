#!/bin/bash
yum update -y
yum install amazon-cloudwatch-agent awscli jq -y  # Added jq explicitly

# Configure CloudWatch Agent
echo '{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/queue.log",
            "log_group_name": "/aws/ec2/WorkerQueue",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          }
        ]
      }
    }
  }
}' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Ensure log files exist and are writable
touch /var/log/queue.log /var/log/rawmsg.log
chown ec2-user:ec2-user /var/log/queue.log /var/log/rawmsg.log  # Adjust ownership as needed
chmod 644 /var/log/queue.log /var/log/rawmsg.log

# Infinite loop to process SQS messages
while true; do
  # Receive message from SQS
  msg=$(aws sqs receive-message --queue-url https://sqs.us-east-1.amazonaws.com/975050183964/MySQS --region us-east-1)

  # Check if message is non-empty and contains Messages array
  if [ -n "$msg" ] && echo "$msg" | jq -e '.Messages[0]' > /dev/null 2>&1; then
    # Log raw message for debugging
    echo "$msg" >> /var/log/rawmsg.log

    # Extract fields from the message
    body=$(echo "$msg" | jq -r '.Messages[0].Body')  
    order_id=$(echo "$body" | jq -r '.order_id')  
    source=$(echo "$body" | jq -r '.source')  
    receipt_handle=$(echo "$msg" | jq -r '.Messages[0].ReceiptHandle')  

    # Log the processed message
    echo "$(date '+%Y-%m-%d %H:%M:%S') Processing order_id=$order_id from $source" >> /var/log/queue.log

    # Send metric to CloudWatch
    aws cloudwatch put-metric-data --namespace WorkerMetrics --metric-name OrdersProcessed --value 1 --region us-east-1

    # Simulate processing time
    sleep 30

    # Delete the message from SQS using the stored receipt_handle
    aws sqs delete-message --queue-url https://sqs.us-east-1.amazonaws.com/975050183964/MySQS --region us-east-1 --receipt-handle "$receipt_handle"
  else
    # Log if no message was received (optional debugging)
    echo "$(date '+%Y-%m-%d %H:%M:%S') No message received" >> /var/log/queue.log
  fi
  sleep 10
done