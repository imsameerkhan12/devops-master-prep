output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used for IRSA role trust policies"
  value       = module.eks.oidc_provider_arn
}

output "node_group_role_arn" {
  value = module.eks.eks_managed_node_groups["devops-lab"].iam_role_arn
}
