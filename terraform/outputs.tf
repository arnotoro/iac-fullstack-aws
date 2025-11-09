output "frontend_url" {
    description = "URL of the CloudFront distribution for the frontend"
    value       = aws_cloudfront_distribution.frontend_cf.domain_name
}

output "backend_url" {
  value = aws_cloudfront_distribution.backend_cf.domain_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

# debug
# output "alb_dns_name" {
#   value = aws_lb.backend_alb.dns_name
# }
# output "backend_ecr_url" {
#   value = local.backend_ecr_url
# }