#!/usr/bin/env bash
set -e

ECR_REPO_NAME="lambda-docker-repo"
AWS_REGION="us-east-1"

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_REPO_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1 || true

# Build (x86_64 example; match Lambda architectures)
docker buildx build --platform linux/amd64 --provenance=false -t "${ECR_REPO_NAME}:latest" ./worker_lambda

# Login & push
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REPO_URI"
docker tag "${ECR_REPO_NAME}:latest" "${ECR_REPO_URI}:latest"
docker push "${ECR_REPO_URI}:latest"
# remove previous exports of this var (if any)
sed -i '/^export TF_VAR_ecr_repo_url=/d' ~/.bashrc

DIGEST=$(aws ecr describe-images \
  --repository-name "$ECR_REPO_NAME" \
  --image-ids imageTag=latest \
  --query 'imageDetails[0].imageDigest' \
  --output text \
  --region "$AWS_REGION")

IMAGE_URI="${ECR_REPO_URI}@${DIGEST}"
echo "Resolved image digest: $IMAGE_URI"

# Export for Terraform
export TF_VAR_ecr_repo_url="$IMAGE_URI"
if grep -q '^export TF_VAR_ecr_repo_url=' "$HOME/.bashrc"; then
  sed -i "s|^export TF_VAR_ecr_repo_url=.*|export TF_VAR_ecr_repo_url=${IMAGE_URI}|" "$HOME/.bashrc"
else
  echo "export TF_VAR_ecr_repo_url=${IMAGE_URI}" >> "$HOME/.bashrc"
fi
echo "TF_VAR_ecr_repo_url=${TF_VAR_ecr_repo_url}"
 
source ~/.bashrc

set +e