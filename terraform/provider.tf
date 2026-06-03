terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name         = "eks-karpenter-obsv"
  cluster_name = "${local.name}-${var.environment}"
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  common_tags = var.enable_resource_tags ? {
    Project     = "eks-karpenter-observability-lab"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "learning"
  } : {}
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

resource "time_sleep" "cluster_endpoint_settle" {
  create_duration = "90s"

  depends_on = [module.eks]
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name suffix"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Keep updated to latest stable supported by your region."
  type        = string
  default     = "1.33"
}

variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.3.2"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "fraud-detection-service"
}

variable "enable_karpenter_manifests" {
  description = "Create Karpenter EC2NodeClass/NodePool manifests after EKS cluster is up and reachable"
  type        = bool
  default     = false
}

variable "enable_resource_tags" {
  description = "Apply Terraform tags to resources. Disable when IAM lacks iam:TagRole and related tag permissions."
  type        = bool
  default     = false
}

variable "enable_alb_controller" {
  description = "Deploy AWS Load Balancer Controller and its IRSA role"
  type        = bool
  default     = false
}

variable "alb_controller_policy_arn" {
  description = "Existing IAM policy ARN for AWS Load Balancer Controller (must already exist)"
  type        = string
  default     = null

  validation {
    condition     = !var.enable_alb_controller || var.alb_controller_policy_arn != null
    error_message = "Set alb_controller_policy_arn when enable_alb_controller is true. This config does not create IAM policies."
  }
}
