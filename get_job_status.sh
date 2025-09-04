#!/bin/bash
(
cd terraform || exit
API_URL=$(terraform output -raw api_base_url)
curl -X GET $API_URL/jobs   -H "Content-Type: application/json"   -d '{"params": {"sql_1": "true"}}'


)



