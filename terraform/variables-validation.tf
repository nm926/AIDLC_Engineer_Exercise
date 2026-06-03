"""
Terraform variable validation module for infrastructure as code best practices.

This module provides reusable validation functions for common variable patterns.
"""

# Variable Validation Examples

# ============================================================================
# EKS Cluster Variables with Validation
# ============================================================================

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  
  validation {
    condition     = can(regex("^1\\.(2[7-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.27 or later."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9\\-]{3,63}$", var.cluster_name))
    error_message = "Cluster name must be 3-63 lowercase alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Environment name (local, staging, production)"
  type        = string
  
  validation {
    condition     = contains(["local", "staging", "production"], var.environment)
    error_message = "Environment must be 'local', 'staging', or 'production'."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1)."
  }
}

# ============================================================================
# Bootstrap Node Group Variables with Validation
# ============================================================================

variable "bootstrap_instance_type" {
  description = "EC2 instance type for bootstrap node group"
  type        = string
  default     = "t4g.small"
  
  validation {
    condition     = can(regex("^[a-z][0-9][a-z]\\.[a-z]+$", var.bootstrap_instance_type))
    error_message = "Instance type must be valid format (e.g., t4g.small)."
  }
}

variable "bootstrap_desired_size" {
  description = "Desired number of bootstrap nodes"
  type        = number
  default     = 2
  
  validation {
    condition     = var.bootstrap_desired_size >= 1 && var.bootstrap_desired_size <= 10
    error_message = "Bootstrap desired size must be between 1 and 10."
  }
}

variable "bootstrap_max_size" {
  description = "Maximum number of bootstrap nodes"
  type        = number
  default     = 5
  
  validation {
    condition     = var.bootstrap_max_size >= 1 && var.bootstrap_max_size <= 20
    error_message = "Bootstrap max size must be between 1 and 20."
  }
}

# ============================================================================
# Karpenter Provisioner Variables with Validation
# ============================================================================

variable "karpenter_enabled" {
  description = "Enable Karpenter for spot instance management"
  type        = bool
  default     = true
}

variable "spot_instance_pool_size" {
  description = "Number of diverse instance types for spot pool"
  type        = number
  default     = 3
  
  validation {
    condition     = var.spot_instance_pool_size >= 1 && var.spot_instance_pool_size <= 5
    error_message = "Spot pool size must be between 1 and 5."
  }
}

variable "consolidation_enabled" {
  description = "Enable Karpenter consolidation"
  type        = bool
  default     = true
}

# ============================================================================
# VPC Variables with Validation
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "Number of availability zones"
  type        = number
  default     = 2
  
  validation {
    condition     = var.availability_zones >= 2 && var.availability_zones <= 3
    error_message = "Availability zones must be between 2 and 3."
  }
}

# ============================================================================
# Observability Variables with Validation
# ============================================================================

variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 15
  
  validation {
    condition     = var.prometheus_retention_days >= 1 && var.prometheus_retention_days <= 365
    error_message = "Retention must be between 1 and 365 days."
  }
}

variable "loki_retention_days" {
  description = "Loki log retention in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.loki_retention_days >= 1 && var.loki_retention_days <= 30
    error_message = "Retention must be between 1 and 30 days."
  }
}

variable "enable_observability" {
  description = "Enable observability stack"
  type        = bool
  default     = true
}

# ============================================================================
# Security Variables with Validation
# ============================================================================

variable "enable_private_api_endpoint" {
  description = "Enable private API endpoint for EKS cluster"
  type        = bool
  default     = false
}

variable "public_api_enabled" {
  description = "Enable public API endpoint"
  type        = bool
  default     = true
  
  validation {
    condition = (
      var.enable_private_api_endpoint == true ||
      var.public_api_enabled == true
    )
    error_message = "At least one API endpoint (private or public) must be enabled."
  }
}

variable "log_types" {
  description = "List of EKS cluster logs to enable"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for log_type in var.log_types :
      contains([
        "api",
        "audit",
        "authenticator",
        "controllerManager",
        "scheduler"
      ], log_type)
    ])
    error_message = "Log types must be valid EKS log types."
  }
}

# ============================================================================
# Tags and Labels Variables with Validation
# ============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
  
  validation {
    condition = alltrue([
      for key, value in var.tags :
      can(regex("^[a-zA-Z0-9_\\-/:\\.]+$", key)) &&
      can(regex("^[a-zA-Z0-9_\\-/:\\.\\s]+$", value))
    ])
    error_message = "Tag keys and values must contain only alphanumeric, hyphens, underscores, colons, periods, and slashes."
  }
}

variable "required_tags" {
  description = "Required tags for all resources"
  type        = list(string)
  default     = ["Environment", "Application", "CostCenter"]
  
  validation {
    condition = alltrue([
      for tag in var.required_tags :
      contains(keys(var.tags), tag)
    ])
    error_message = "All required tags must be present in tags variable."
  }
}

# ============================================================================
# Locals for Validation and Derived Values
# ============================================================================

locals {
  # Validate environment-specific settings
  is_production = var.environment == "production"
  
  # Enforce stricter requirements for production
  min_replicas = local.is_production ? 3 : 1
  min_azs      = local.is_production ? 3 : 2
  
  # Tags to merge with user-provided tags
  default_tags = {
    "Managed-By" = "Terraform"
    "Environment" = var.environment
    "Creation-Time" = timestamp()
  }
  
  # Merge default and user tags
  all_tags = merge(local.default_tags, var.tags)
  
  # Validation check for production environment
  validate_production = (
    local.is_production ? (
      length(var.cluster_name) > 0 &&
      var.bootstrap_desired_size >= local.min_replicas &&
      var.availability_zones >= local.min_azs
    ) : true
  )
}

# ============================================================================
# Output Validation Examples
# ============================================================================

output "validation_summary" {
  description = "Summary of infrastructure validation"
  value = {
    environment     = var.environment
    cluster_version = var.cluster_version
    region          = var.region
    production_mode = local.is_production
    validation_ok   = local.validate_production
    resource_tags   = local.all_tags
  }
}

# ============================================================================
# Check Block for Runtime Validation
# ============================================================================

# Example check block for dependent variable validation
# (Requires Terraform >= 1.2)
# check "cluster_settings" {
#   assert = (
#     var.bootstrap_desired_size <= var.bootstrap_max_size
#   )
#   error_message = "Desired size cannot exceed maximum size."
# }
