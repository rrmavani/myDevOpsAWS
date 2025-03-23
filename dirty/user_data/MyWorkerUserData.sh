#!/bin/bash
yum update -y
yum install amazon-cloudwatch-agent awscli -y
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
while true; do
  msg=$(aws sqs receive-message --queue-url <SQS-URL> --region us-east-1)
  if [ -n "$msg" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Processing order_id=$(echo $msg | jq -r '.Body | fromjson | .order_id') from $(echo $msg | jq -r '.Body | fromjson | .source')" >> /var/log/queue.log
    aws cloudwatch put-metric-data --namespace WorkerMetrics --metric-name OrdersProcessed --value 1 --region us-east-1
    sleep 30
    aws sqs delete-message --queue-url <SQS-URL> --region us-east-1 --receipt-handle "$(echo $msg | jq -r '.Messages[0].ReceiptHandle')"
  fi
  sleep 1
done