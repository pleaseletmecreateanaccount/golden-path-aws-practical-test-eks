variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "825566110381"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "golden-path"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# ─── Networking ──────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (NAT GWs live here)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# ─── EKS ─────────────────────────────────────────────────────────────────────
variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

# On-Demand node group (fallback)
variable "node_instance_types" {
  description = "Instance types for the On-Demand node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

# Spot node group (primary)
variable "spot_instance_types" {
  description = "Instance types for the Spot node group (multiple for diversification)"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t2.medium"]
}

variable "spot_desired_size" {
  type    = number
  default = 2
}

variable "spot_min_size" {
  type    = number
  default = 0
}

variable "spot_max_size" {
  type    = number
  default = 10
}

# ─── Application ─────────────────────────────────────────────────────────────
variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "golden-path"
}

variable "app_service_account_name" {
  description = "Kubernetes service account name for the application"
  type        = string
  default     = "golden-path-app"
}

variable "external_secrets_service_account" {
  description = "Service account name for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

# ─── Secrets ─────────────────────────────────────────────────────────────────
variable "db_password" {
  description = "Database password to store in Secrets Manager"
  type        = string
  sensitive   = true
  default     = "change-me-in-ci"
}
