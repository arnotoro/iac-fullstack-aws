variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-west-1"
}

variable "S3_bucket_name" {
  description = "The name of the S3 bucket for frontend hosting, must be globally unique"
  type        = string
  default     = "op-kiitorata-frontend-bucket-"
}