# myDevOpsAWS

Make sure to download key

#### Environment variables
````
export AWS_PROFILE=<AWS Profile>
export AWS_PAGER=""
export S3_BUCKET_NAME=<Bucket for stat file>
export DYNAMODB_TABLE_NAME=<Dynamodb table for lock>
````


#### Terraform init
```
rm -rf .terraform && rm -rf .terraform.lock.hcl && terraform init -reconfigure \
-backend-config="bucket=${S3_BUCKET_NAME}" \
-backend-config="dynamodb_table=${DYNAMODB_TABLE_NAME}" 
```




