#!/bin/bash
yum update -y
yum install httpd awscli -y
systemctl start httpd
systemctl enable httpd
echo "<h1>Submit Order</h1><form action='/submit' method='POST'><input type='submit' value='Place Order'></form>" > /var/www/html/index.html
QUEUE_URL="<SQS-URL>"
cat << EOF > /var/www/html/submit.sh
#!/bin/bash
aws sqs send-message --queue-url ${QUEUE_URL} --region us-east-1 --message-body "{\"order_id\": "$RANDOM", \"task\": \"process_order\", \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\", \"source\": \"$(hostname)\"}" > /dev/null 2>&1
echo "Content-type: text/html"
echo ""
echo "<html><body><h1>Order Submitted</h1><p>Order has been sent to the queue.</p></body></html>"
EOF
chmod +x /var/www/html/submit.sh
cat << EOF > /etc/httpd/conf.d/rewrite.conf
<VirtualHost *:80>
    DocumentRoot /var/www/html
    <Directory "/var/www/html">
        Options +ExecCGI
        AddHandler cgi-script .sh
        AllowOverride All
        Require all granted
    </Directory>
    RewriteEngine On
    RewriteRule ^/submit$ /submit.sh [L]
</VirtualHost>
EOF
systemctl restart httpd