# outputs.tf — tofu apply ke baad important values print karo

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "oidc_provider_arn" {
  description = "Use this for IRSA role trust policies"
  value       = module.eks.oidc_provider_arn
}

output "kubectl_config_command" {
  description = "Run this after tofu apply to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name} --profile ${var.aws_profile}"
}
