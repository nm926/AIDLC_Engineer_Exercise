module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.13.1"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  enable_irsa = true

  create_cloudwatch_log_group = false

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    bootstrap_arm = {
      name = "bootstrap-arm"

      subnet_ids = module.vpc.public_subnets

      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = ["t4g.small"]
      capacity_type  = "ON_DEMAND"

      min_size     = 3
      max_size     = 4
      desired_size = 3

      # Prevent managed node group updates from failing when strict PDBs block drain retries.
      force_update_version = true

      labels = {
        workload = "bootstrap"
        arch     = "arm64"
      }
    }
  }
  self_managed_node_groups = {}

  cluster_addons = {
    coredns = {
      most_recent = true
      preserve = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.common_tags
}
