# These import blocks tell Terraform that the access entry and policy association
# for GitHubActionsRole already exist in AWS — it will adopt them instead of
# trying to create them (which would cause a 409 ResourceInUseException).

import {
  to = module.eks.aws_eks_access_entry.github_actions
  id = "golden-path-production,arn:aws:iam::825566110381:role/GitHubActionsRole"
}

import {
  to = module.eks.aws_eks_access_policy_association.github_actions_admin
  id = "golden-path-production#arn:aws:iam::825566110381:role/GitHubActionsRole#arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}
