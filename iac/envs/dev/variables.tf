# variables.tf — sab inputs declare karo, default values optional

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "sameer"
}

variable "cluster_name" {
  type    = string
  default = "devops-lab-eks"
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_desired" {
  type    = number
  default = 1
}

variable "tags" {
  type = map(string)
  default = {
    project     = "devops-lab"
    environment = "dev"
    managed_by  = "opentofu"
  }
}
