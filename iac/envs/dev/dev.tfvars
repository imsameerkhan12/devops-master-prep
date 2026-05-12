# dev.tfvars — dev environment ke specific values
# Production ke liye alag file hogi: prod.tfvars (alag account, bigger nodes, more replicas)
# Use karo: tofu apply -var-file=dev.tfvars

aws_region  = "us-east-1"
aws_profile = "sameer"

cluster_name    = "devops-lab-eks"
cluster_version = "1.33"

node_instance_type = "t3.medium"
node_desired       = 1

tags = {
  project     = "devops-lab"
  environment = "dev"
  managed_by  = "opentofu"
}
