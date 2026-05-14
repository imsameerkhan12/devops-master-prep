# EKS Module
# Uses community terraform-aws-modules/eks v20.x
# Includes: cluster, managed node group, all add-ons, EKS access entry
#
# IAM approach: Pod Identity for all addons (NOT IRSA)
#   Pod Identity = simpler, no OIDC federation needed, same-account standard
#   IRSA = only needed for cross-account access (not our case)

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Public + private endpoint — kubectl from laptop works
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Automatically gives cluster creator admin access
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
      # Pod Identity association created explicitly below — cleaner + explicit
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    metrics-server = {
      most_recent = true
    }
  }

  # Managed Node Group
  eks_managed_node_groups = {
    devops-lab = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_min
      max_size       = var.node_max
      desired_size   = var.node_desired

      ami_type  = "AL2023_x86_64_STANDARD"
      disk_size = 20

      subnet_ids = var.node_subnet_ids

      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  tags = var.tags
}

# IAM Role for EBS CSI driver — Pod Identity trust policy
# pods.eks.amazonaws.com = Pod Identity ka principal (OIDC nahi)
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Pod Identity Association — EBS CSI addon ke liye
# Explicit resource — module ke internal attribute pe depend nahi karte
# Cluster + addon exist karne ke baad banta hai (depends_on via cluster_name reference)
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}

# Access Entry not needed here —
# enable_cluster_creator_admin_permissions = true already creates
# an admin access entry for whoever runs tofu apply (sameer)
# Adding a second entry for the same user = ResourceInUseException
