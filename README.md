# Infrastructure as Code for fullstack app on AWS
This repository contains the code for a simple fullstack application that can be deployed on AWS using Terraform. The application asks for two numbers from the user and returns their sum by making an API call to the backend.

## Features
- **Frontend**: Static React app hosted on an S3 bucket and served via CloudFront
- **Backend**: Containerized Express backend running on ECS Fargate behind an Application Load Balancer

## Architecture
The fullstack application is deployed using the following AWS services:
- **S3**: Hosts the static files for the React frontend.
- **CloudFront**: Provides a CDN for both the frontend and backend, with HTTPS support.
- **Elastic Container Registry (ECR)**: Stores the Docker image for the Express backend.
- **Elastic Container Service (ECS) Fargate**: Runs the containerized backend service.
- **Application Load Balancer (ALB)**: Distributes incoming traffic to the backend service.
- **Virtual private cloud (VPC)**: Configures networking and internet access for the backend service.

## Prerequisites
Before deploying, make sure you meet the following requirements:
- An AWS account with permissions to create the required resources given in the architecture section.
- Terraform (tested on the latest version v1.13.5)
- AWS CLI configured ([see AWS CLI setup guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html))
- Docker installed to build and push the backend image to ECR
- Node.js and npm installed to build the React frontend

## Deployment using Terraform
Terraform will create all the neccessary AWS resources. There are two variables you can customize when applying the configuration by passing them as `-var` arguments in the deployment stage or by changing the default values in `variables.tf`:
- `aws_region` (defaults to `eu-west-1`)
- `S3_bucket_name` (defaults to `op-kiitorata-frontend-bucket-XXXXXXXX`)

### Steps to deploy
1. Clone this repository:
```bash
git clone https://github.com/arnotoro/iac-fullstack-aws
```
2. Navigate to the terraform directory and initialize Terraform:
```bash
cd terraform
terraform init
```
3. Preview and apply the Terraform configuration and accept the changes by typing `yes` when prompted:
```bash
terraform plan
terraform apply
```

Once the deployment finishes, Terraform will output the following important information:
- `frontend_url`: URL to the website served via CloudFront
- `backend_url`: URL to the backend API served via ALB, useful for testing
- `s3_bucket_name`: Name of the S3 bucket hosting the frontend 

## Cleanup
To remove the deployed resources, run the following command in the `terraform` directory, again typing `yes` when prompted:
```bash
terraform destroy
```

### Non-idelities
- The way the project is deployed to AWS may not be the most optimal or cost-efficient way. 
- The front and backend are built with Terraform using `null_resource` and `local-exec` provisioners. The reason behind this choice was to make the project deployable with a single command.
- The Terraform `null_resource` with `local-exec` provisioners relies on Windows PowerShell, making the project non-portable to Unix-based systems. This somewhat defeats the purpose of infrastructure-as-code.
- Network security groups allow all outbound traffic for simplicity. There is effectively no firewall for backend.
