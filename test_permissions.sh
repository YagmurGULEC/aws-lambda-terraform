
#!/bin/bash

set -e
AWS_REGION="us-east-1"

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)



aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::${ACCOUNT_ID}:role/data-processor-exec-role \
  --action-names athena:GetWorkGroup \
  --resource-arns arn:aws:athena:${AWS_REGION}:${ACCOUNT_ID}:workgroup/dash-wg