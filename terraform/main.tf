# terrform settings
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


# AWS region, default to eu-west-1
provider "aws" {
    region = var.aws_region
}

# local variables
locals {
  # check if ECR repository exists for docker image
  backend_ecr_url = length(data.aws_ecr_repository.existing) > 0 ? data.aws_ecr_repository.existing[0].repository_url : aws_ecr_repository.backend_repo[0].repository_url
}

# S3 bucket for frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.S3_bucket_name}${random_id.bucket_id.hex}"
  force_destroy = true
}

# random ID for unique bucket name
resource "random_id" "bucket_id" {
  byte_length = 4
}

# configuration for S3 static website host
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# S3 bucket policy to allow cloudfront access
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
      Statement = [
          {
              Effect = "Allow"
              Principal = {
                  AWS = aws_cloudfront_origin_access_identity.frontend_oai.iam_arn
              }
              Action = "s3:GetObject"
              Resource = "${aws_s3_bucket.frontend.arn}/*"
          }
      ]
  })
}

# cloudfront for frontend

# OAI to access S3 bucket files
resource "aws_cloudfront_origin_access_identity" "frontend_oai" {}

# cloudfront distribution configuration
resource "aws_cloudfront_distribution" "frontend_cf" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "frontend-s3"

    s3_origin_config {
    origin_access_identity = aws_cloudfront_origin_access_identity.frontend_oai.cloudfront_access_identity_path
    }
  }

  enabled = true
  is_ipv6_enabled = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = [ "GET", "HEAD" ]
    cached_methods  = [ "GET", "HEAD" ]
    target_origin_id = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }  
}

# frontend build and deployment, injecting backend URL into environment variables
resource "null_resource" "frontend_deploy" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    # using powershell, since development was done on windows
    interpreter = ["PowerShell", "-Command"]
    command = <<EOT
      Set-Location "${path.module}/../frontend"
      'VITE_API_URL="https://${aws_cloudfront_distribution.backend_cf.domain_name}"' | Out-File -Encoding ASCII .env.production

      npm install
      npm run build
      if ($LASTEXITCODE -ne 0) { throw "Frontend build failed" }

      aws s3 sync .\dist s3://${aws_s3_bucket.frontend.bucket} --delete
      if ($LASTEXITCODE -ne 0) { throw "S3 sync failed" }

      aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend_cf.id} --paths "/*"
    EOT
  }

  depends_on = [
    aws_ecs_service.backend_service, # ensure backend is deployed first
    aws_cloudfront_distribution.backend_cf,
    aws_s3_bucket.frontend,
    aws_cloudfront_distribution.frontend_cf
  ]
}

# backend network infrastructure
data "aws_availability_zones" "available" {}

# virtual private cloud
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# public subnets
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
}

# internet gateway for public access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# associate route table with public subnets
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


# backend ECR repository
data "aws_ecr_repository" "existing" {
  name = var.backend_ecr_name
  count = 1
}

resource "aws_ecr_repository" "backend_repo" {
  name = var.backend_ecr_name
  count = length(data.aws_ecr_repository.existing) == 0 ? 1 : 0
  force_delete = true
}

# build and push backend Docker image to ECR repository
resource "null_resource" "backend_docker_build" {
  triggers = {
    repo_url = local.backend_ecr_url
    always_run = timestamp()
  }

    provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.backend_ecr_url}
      echo "Building backend Docker image..."
      docker build -t ${var.backend_ecr_name} ../backend
      docker tag ${var.backend_ecr_name}:latest ${local.backend_ecr_url}:latest
      docker push ${local.backend_ecr_url}:latest
    EOT
  }
}

# ECS cluster for backend service
resource "aws_ecs_cluster" "backend" {
  name = "backend-cluster"
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecRole-kiitorata"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS task definition for backend container
resource "aws_ecs_task_definition" "backend" {
  family                   = "backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${local.backend_ecr_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
    }
  ])

  depends_on = [null_resource.backend_docker_build] # ensure image is built and pushed before task definition
} 

# security group for ECS service
resource "aws_security_group" "ecs_service" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# allow ALB to communicate with ECS service on port 3000
resource "aws_security_group_rule" "alb_to_ecs" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  security_group_id = aws_security_group.ecs_service.id
  cidr_blocks       = ["0.0.0.0/0"]
}


# ALB for backend service
resource "aws_lb" "backend_alb" {
  name               = "backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_service.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "backend_tg" {
  name     = "backend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.backend_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}


# ECS service for backend
resource "aws_ecs_service" "backend_service" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.backend.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_service.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "backend"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.backend_listener]
}

# cloudfront distribution for backend to allow HTTPS access
resource "aws_cloudfront_distribution" "backend_cf" {
  origin {
    domain_name = aws_lb.backend_alb.dns_name
    origin_id   = "backend-alb"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = [ "TLSv1.2" ]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = ""

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "backend-alb"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}