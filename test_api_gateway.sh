#!/bin/bash
(
cd terraform || exit
API_URL=$(terraform output -raw api_base_url)
RESPONSE=$(curl -X POST $API_URL/jobs   -H "Content-Type: application/json"   -d '{"params": {"sql_1": "true","sql_2":"true"}}')
JOB_ID=$(echo "$RESPONSE" | jq -r .job_id)

# Step 3: Wait a few seconds for processing
sleep 10

# Step 4: Check job status
echo "$API_URL/jobs/$JOB_ID"
curl -X GET "$API_URL/jobs/$JOB_ID" \
  -H "Content-Type: application/json"

)