# outputs.tf — module se bahar expose karo
# Doosra module (eks) inhe use karega

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs — EKS nodes yahan chalenge"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs — future load balancer ke liye"
  value       = module.vpc.public_subnets
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr_block
}

