1. First build the image and push it to the ECR and then set the Terraform variable for ECR repo url. 
```
source deploy_lambda_docker.sh
```
2. Then go to infra/
```
cd infra/
terraform init
terraform apply -auto-approve
```