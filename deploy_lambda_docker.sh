#!/bin/bash

ECR_REPO_NAME="lambda-docker-repo"
AWS_REGION="us-east-1"

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

aws ecr create-repository --repository-name $ECR_REPO_NAME || true

ECR_REPO_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
docker buildx build --platform linux/amd64 --provenance=false -t $ECR_REPO_NAME ./lambda_handler

# Login & push
aws ecr get-login-password --region $AWS_REGION \
| docker login --username AWS --password-stdin $ECR_REPO_URI

docker tag $ECR_REPO_NAME:latest $ECR_REPO_URI:latest
docker push $ECR_REPO_URI:latest
# Get the digest for the tag we just pushed
DIGEST=$(aws ecr describe-images \
  --repository-name "$ECR_REPO_NAME" \
  --image-ids imageTag=latest \
  --query 'imageDetails[0].imageDigest' \
  --output text \
  --region "$AWS_REGION")

IMAGE_URI="${ECR_REPO_URI}@${DIGEST}"
# Define the variables to manage
declare -A TF_VARS=(
 
  ["TF_VAR_ecr_repo_url"]="$IMAGE_URI"
)

for var in "${!TF_VARS[@]}"; do
    value="${TF_VARS[$var]}"
    if grep -q "^export $var=" "$HOME/.bashrc"; then
        sed -i "s|^export $var=.*|export $var=$value|" "$HOME/.bashrc"
    else
        echo "export $var=$value" >> "$HOME/.bashrc"
    fi
done

source $HOME/.bashrc
# Run the Lambda Runtime Interface Emulator built into the base image
# docker run -p 9000:8080 $ECR_REPO_NAME

# curl -s -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'



