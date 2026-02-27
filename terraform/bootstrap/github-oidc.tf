##############################################################################
# GitHub Actions IAM Role (OIDC)
# Creates the IAM role that GitHub Actions assumes — no AWS access keys needed.
# Run this once in the bootstrap phase.
##############################################################################

variable "github_org"  { default = "pleaseletmecreateanaccount" }
variable "github_repo" { default = "golden-path-aws-practical-test-eks" }

# GitHub OIDC Provider (create once per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's current OIDC thumbprint (stable)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Allow main branch and workflow_dispatch from any branch
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-golden-path"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
  description        = "Role assumed by GitHub Actions for the Golden Path project"
}

# For a practical test, AdministratorAccess is fine.
# In production, scope this down to exactly what Terraform needs.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Set this as the AWS_ROLE_ARN secret in GitHub"
}
