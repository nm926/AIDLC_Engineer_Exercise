# Comprehensive Terraform Outputs Organization
# Organized by component and use case for easy reference

# ============================================================================
# EKS Cluster Outputs
# ============================================================================

output "eks_cluster" {
  description = "EKS cluster information"
  value = {
    name               = aws_eks_cluster.main.name
    version            = aws_eks_cluster.main.version
    arn                = aws_eks_cluster.main.arn
    endpoint           = aws_eks_cluster.main.endpoint
    created_at         = aws_eks_cluster.main.created_at
    platform_version   = aws_eks_cluster.main.platform_version
    status             = aws_eks_cluster.main.status
  }
}

output "eks_cluster_arn" {
  description = "ARN of EKS cluster"
  value       = aws_eks_cluster.main.arn
  sensitive   = false
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS cluster API server"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_name" {
  description = "Name of EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_version" {
  description = "Version of EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_certificate_authority" {
  description = "Base64 encoded certificate data for cluster"
  value = {
    data = aws_eks_cluster.main.certificate_authority[0].data
  }
  sensitive = true
}

# ============================================================================
# Node Group Outputs
# ============================================================================

output "bootstrap_node_group" {
  description = "Bootstrap node group details"
  value = {
    name            = aws_eks_node_group.bootstrap.node_group_name
    arn             = aws_eks_node_group.bootstrap.arn
    capacity_type   = aws_eks_node_group.bootstrap.capacity_type
    instance_types  = aws_eks_node_group.bootstrap.instance_types
    desired_size    = aws_eks_node_group.bootstrap.scaling_config[0].desired_size
    min_size        = aws_eks_node_group.bootstrap.scaling_config[0].min_size
    max_size        = aws_eks_node_group.bootstrap.scaling_config[0].max_size
  }
}

output "node_group_status" {
  description = "Status of node groups"
  value = {
    bootstrap_status = aws_eks_node_group.bootstrap.status
    bootstrap_health = aws_eks_node_group.bootstrap.health[0]
  }
}

output "node_group_launch_template" {
  description = "Launch template used by node groups"
  value = {
    id      = aws_launch_template.node_group.id
    name    = aws_launch_template.node_group.name
    version = aws_launch_template.node_group.latest_version_number
  }
}

# ============================================================================
# Karpenter Outputs
# ============================================================================

output "karpenter" {
  description = "Karpenter configuration details"
  value = {
    enabled              = var.karpenter_enabled
    provisioner_name     = "default"
    consolidation_enabled = true
  }
}

output "karpenter_provisioner_config" {
  description = "Karpenter provisioner configuration"
  value = {
    ttl_seconds_after_empty       = 30
    ttl_seconds_until_expired     = 604800  # 7 days
    consolidation_enabled         = true
    consolidation_ttl_seconds     = 30
  }
}

# ============================================================================
# VPC/Network Outputs
# ============================================================================

output "vpc" {
  description = "VPC information"
  value = {
    id            = aws_vpc.main.id
    cidr_block    = aws_vpc.main.cidr_block
    enable_dns    = aws_vpc.main.enable_dns_hostnames
  }
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "availability_zones" {
  description = "Availability zones used"
  value       = data.aws_availability_zones.available.names
}

# ============================================================================
# Security Group Outputs
# ============================================================================

output "security_groups" {
  description = "Security group IDs"
  value = {
    cluster_sg           = aws_security_group.cluster.id
    node_sg              = aws_security_group.node.id
    ingress_controller_sg = aws_security_group.ingress_controller.id
  }
}

output "ingress_controller_sg_id" {
  description = "Security group ID for ingress controller"
  value       = aws_security_group.ingress_controller.id
}

# ============================================================================
# IAM Outputs
# ============================================================================

output "iam_roles" {
  description = "IAM roles created"
  value = {
    cluster_role    = aws_iam_role.cluster.arn
    node_role       = aws_iam_role.node.arn
    karpenter_role  = aws_iam_role.karpenter.arn
  }
}

output "cluster_role_arn" {
  description = "ARN of EKS cluster IAM role"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "ARN of EKS node IAM role"
  value       = aws_iam_role.node.arn
}

output "karpenter_role_arn" {
  description = "ARN of Karpenter IAM role"
  value       = aws_iam_role.karpenter.arn
}

output "oidc_provider" {
  description = "OIDC provider information for IRSA"
  value = {
    provider_arn = aws_iam_openid_connect_provider.oidc.arn
    provider_url = aws_iam_openid_connect_provider.oidc.url
  }
}

# ============================================================================
# ECR Outputs
# ============================================================================

output "ecr_repositories" {
  description = "ECR repository information"
  value = {
    app_backend_url  = aws_ecr_repository.app_backend.repository_url
    app_frontend_url = aws_ecr_repository.app_frontend.repository_url
  }
}

output "ecr_app_backend_repository_url" {
  description = "URL of app backend ECR repository"
  value       = aws_ecr_repository.app_backend.repository_url
}

output "ecr_app_frontend_repository_url" {
  description = "URL of app frontend ECR repository"
  value       = aws_ecr_repository.app_frontend.repository_url
}

# ============================================================================
# Kubernetes Addons Outputs
# ============================================================================

output "kubernetes_addons" {
  description = "Kubernetes addons information"
  value = {
    coredns_version = aws_eks_addon.coredns.addon_version
  }
}

output "coredns_addon_status" {
  description = "Status of CoreDNS addon"
  value = {
    addon_version = aws_eks_addon.coredns.addon_version
    service_account_role_arn = aws_eks_addon.coredns.service_account_role_arn
    created_at = aws_eks_addon.coredns.created_at
  }
}

# ============================================================================
# Observability Outputs
# ============================================================================

output "observability" {
  description = "Observability stack configuration"
  value = {
    enabled          = var.enable_observability
    namespace        = "observability"
    prometheus_enabled = true
    loki_enabled     = true
    tempo_enabled    = true
  }
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring"
  value       = kubernetes_namespace.observability.metadata[0].name
}

# ============================================================================
# Application Namespace Outputs
# ============================================================================

output "application_namespace" {
  description = "Kubernetes namespace for applications"
  value       = kubernetes_namespace.application.metadata[0].name
}

output "fraud_detection_config_map" {
  description = "ConfigMap name for fraud detection service"
  value       = kubernetes_config_map.fraud_service_code.metadata[0].name
}

# ============================================================================
# Load Generator Outputs
# ============================================================================

output "load_generator_deployment" {
  description = "Load generator deployment name"
  value       = kubernetes_deployment.load_generator.metadata[0].name
}

# ============================================================================
# CloudWatch Logs Group Outputs
# ============================================================================

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value = {
    eks_cluster_logs = "/aws/eks/${aws_eks_cluster.main.name}/cluster"
  }
}

# ============================================================================
# Access Information Outputs
# ============================================================================

output "kubectl_config" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${data.aws_region.current.name}"
}

output "kubernetes_access" {
  description = "Information for accessing Kubernetes cluster"
  value = {
    cluster_name = aws_eks_cluster.main.name
    region       = data.aws_region.current.name
    arn          = aws_eks_cluster.main.arn
    endpoint     = aws_eks_cluster.main.endpoint
  }
}

# ============================================================================
# Debugging Outputs
# ============================================================================

output "debugging_info" {
  description = "Useful debugging information"
  value = {
    region                = data.aws_region.current.name
    account_id            = data.aws_caller_identity.current.account_id
    cluster_version       = aws_eks_cluster.main.version
    cluster_platform_version = aws_eks_cluster.main.platform_version
  }
}

output "helm_values_integration" {
  description = "Values useful for Helm chart deployments"
  value = {
    cluster_name          = aws_eks_cluster.main.name
    region                = data.aws_region.current.name
    oidc_provider_arn     = aws_iam_openid_connect_provider.oidc.arn
    oidc_provider_url     = aws_iam_openid_connect_provider.oidc.url
    node_role_arn         = aws_iam_role.node.arn
  }
}
