#!/bin/bash


PAYLOAD=$(echo -n '{}' | base64)
aws --endpoint-url=http://localhost:4566 lambda invoke \
  --function-name matrix-mul \
  --payload "$PAYLOAD" \
  /tmp/out.json

cat /tmp/out.json
