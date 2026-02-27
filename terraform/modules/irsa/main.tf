##############################################################################
# IRSA Module
# Creates IAM roles bound to Kubernetes service accounts via OIDC federation.
# No static credentials ever touch the application.
##############################################################################

locals {
  oidc_issuer = replace(var.cluster_oidc_issuer_url, "https://", "")
}

# ─── Helper: OIDC trust policy template ──────────────────────────────────────
data "aws_iam_policy_document" "oidc_trust" {
  for_each = {
    app             = { namespace = var.app_namespace,              sa = var.app_service_account_name }
    alb_controller  = { namespace = var.alb_controller_namespace,  sa = var.alb_controller_service_account }
    external_secrets = { namespace = var.external_secrets_namespace, sa = var.external_secrets_service_account }
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.sa}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ─── App Role (S3 Access) ─────────────────────────────────────────────────────
resource "aws_iam_role" "app" {
  name               = "${var.cluster_name}-app-irsa"
  assume_role_policy = data.aws_iam_policy_document.oidc_trust["app"].json
}

data "aws_iam_policy_document" "app_s3" {
  statement {
    sid     = "AllowS3Access"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_policy" "app_s3" {
  name   = "${var.cluster_name}-app-s3-policy"
  policy = data.aws_iam_policy_document.app_s3.json
}

resource "aws_iam_role_policy_attachment" "app_s3" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app_s3.arn
}

# ─── ALB Controller Role ──────────────────────────────────────────────────────
resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.oidc_trust["alb_controller"].json
}

# The official AWS LBC policy document (sourced from the AWS LBC repo)
data "aws_iam_policy_document" "alb_controller" {
  statement {
    sid    = "AllowALBController"
    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones", "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs", "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances", "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags", "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools", "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowALBMutations"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates", "acm:DescribeCertificate",
      "iam:ListServerCertificates", "iam:GetServerCertificate",
      "waf-regional:GetWebACL", "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL", "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL", "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState", "shield:DescribeProtection",
      "shield:CreateProtection", "shield:DeleteProtection",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags", "ec2:DeleteTags",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:DescribeNetworkInterfaceAttribute",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:ModifyListenerAttributes",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowALBCreate"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.cluster_name}-alb-controller-policy"
  policy = data.aws_iam_policy_document.alb_controller.json
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# ─── External Secrets Operator Role ──────────────────────────────────────────
resource "aws_iam_role" "external_secrets" {
  name               = "${var.cluster_name}-external-secrets-irsa"
  assume_role_policy = data.aws_iam_policy_document.oidc_trust["external_secrets"].json
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid = "AllowSecretsManagerRead"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.cluster_name}/*",
    ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${var.cluster_name}-external-secrets-policy"
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}
