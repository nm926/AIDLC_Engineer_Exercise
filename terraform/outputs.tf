output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnets used by ALB and Karpenter nodes"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnets used by control plane and Fargate profiles"
  value       = module.vpc.private_subnets
}

output "ecr_repository_url" {
  description = "ECR repository URL for fraud-detection-service"
  value       = aws_ecr_repository.fraud_detection.repository_url
}
