variable "cluster_name"         { type = string }
variable "cluster_version"      { type = string }
variable "vpc_id"               { type = string }
variable "private_subnet_ids"   { type = list(string) }
variable "aws_region"           { type = string }
variable "aws_account_id"       { type = string }
variable "node_instance_types"  { type = list(string) }
variable "node_desired_size"    { type = number }
variable "node_min_size"        { type = number }
variable "node_max_size"        { type = number }
variable "spot_instance_types"  { type = list(string) }
variable "spot_desired_size"    { type = number }
variable "spot_min_size"        { type = number }
variable "spot_max_size"        { type = number }

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role — granted cluster-admin"
  type        = string
}

variable "admin_iam_role_arn" {
  description = "Optional: ARN of an additional IAM role/user for console/local access"
  type        = string
  default     = ""
}
