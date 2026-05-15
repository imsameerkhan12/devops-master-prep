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
  value       = var.aws_profile != "" ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name} --profile ${var.aws_profile}" : "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name — app lists this"
  value       = aws_s3_bucket.app.id
}

output "s3_reader_role_arn" {
  description = "IAM role ARN for s3-reader Pod Identity"
  value       = aws_iam_role.s3_reader.arn
}

output "github_actions_role_arn" {
  description = "Set this as AWS_ROLE_ARN in GitHub repo variables (Settings → Variables)"
  value       = aws_iam_role.github_actions.arn
}

output "ecr_registry" {
  description = "Set this as ECR_REGISTRY in GitHub repo variables"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}
