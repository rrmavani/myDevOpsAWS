#!/bin/bash
yum update -y
yum install httpd awscli -y
systemctl start httpd
systemctl enable httpd
echo "<h1>Submit Order</h1><form action='/submit' method='POST'><input type='submit' value='Place Order'></form>" > /var/www/html/index.html
QUEUE_URL="<SQS-URL>"
cat << EOF > /var/www/html/submit.sh
#!/bin/bash
aws sqs send-message --queue-url ${QUEUE_URL} --region us-east-1 --message-body "{\"order_id\": "\$RANDOM", \"task\": \"process_order\", \"timestamp\": \"\$(date '+%Y-%m-%d %H:%M:%S')\", \"source\": \"\$(hostname)\"}"
echo "Order sent to queue" > /var/www/html/result.html
EOF
chmod +x /var/www/html/submit.sh
echo "<VirtualHost *:80> RewriteEngine On RewriteRule ^/submit$ /submit.sh [L] </VirtualHost>" > /etc/httpd/conf.d/rewrite.conf
systemctl restart httpd