output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "app_irsa_role_arn" {
  description = "IAM role ARN for the application (IRSA)"
  value       = module.irsa.app_role_arn
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for the ALB controller (IRSA)"
  value       = module.irsa.alb_controller_role_arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator (IRSA)"
  value       = module.irsa.external_secrets_role_arn
}

output "s3_bucket_name" {
  description = "S3 bucket for application data"
  value       = aws_s3_bucket.app_data.id
}

output "db_secret_arn" {
  description = "ARN of the DB password secret in Secrets Manager"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch Golden Signals dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.golden_signals.dashboard_name}"
}
