##############################################################################
# Bootstrap: S3 bucket + DynamoDB for Terraform state
# These are created with a separate "bootstrap" run before the main infra.
# See: ../bootstrap/main.tf
##############################################################################

##############################################################################
# VPC + Networking
##############################################################################
module "vpc" {
  source = "../../modules/vpc"

  name               = "${var.project}-${var.environment}"
  cidr               = var.vpc_cidr
  azs                = var.availability_zones
  private_subnets    = var.private_subnet_cidrs
  public_subnets     = var.public_subnet_cidrs
  cluster_name       = "${var.project}-${var.environment}"
}

##############################################################################
# EKS Cluster (Managed Node Groups)
##############################################################################
module "eks" {
  source = "../../modules/eks"

  cluster_name       = "${var.project}-${var.environment}"
  cluster_version    = var.eks_cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  aws_region         = var.aws_region
  aws_account_id     = var.aws_account_id

  # Node group sizing
  node_instance_types       = var.node_instance_types
  node_desired_size         = var.node_desired_size
  node_min_size             = var.node_min_size
  node_max_size             = var.node_max_size

  # Spot + On-Demand mixed instances (cost & reliability)
  spot_instance_types       = var.spot_instance_types
  spot_desired_size         = var.spot_desired_size
  spot_min_size             = var.spot_min_size
  spot_max_size             = var.spot_max_size
}

##############################################################################
# IRSA — IAM Roles for Service Accounts
##############################################################################
module "irsa" {
  source = "../../modules/irsa"

  cluster_name                       = module.eks.cluster_name
  cluster_oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  aws_account_id                     = var.aws_account_id
  aws_region                         = var.aws_region
  app_namespace                      = var.app_namespace
  app_service_account_name           = var.app_service_account_name
  alb_controller_namespace           = "kube-system"
  alb_controller_service_account     = "aws-load-balancer-controller"
  external_secrets_namespace         = "external-secrets"
  external_secrets_service_account   = "external-secrets"
  s3_bucket_arn                      = aws_s3_bucket.app_data.arn
}

##############################################################################
# S3 bucket for app data (accessed via IRSA — no static keys)
##############################################################################
resource "aws_s3_bucket" "app_data" {
  bucket = "${var.project}-app-data-${var.aws_account_id}"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket                  = aws_s3_bucket.app_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##############################################################################
# AWS Secrets Manager — DB Password
##############################################################################
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project}/${var.environment}/db-password"
  description             = "Database password for ${var.project} ${var.environment}"
  recovery_window_in_days = 0 # For easier teardown in test environments
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "appuser"
    password = var.db_password
  })
}

##############################################################################
# Helm: AWS Load Balancer Controller
##############################################################################
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa.alb_controller_role_arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [module.eks, module.irsa]
}

##############################################################################
# Helm: External Secrets Operator
##############################################################################
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"
  version    = "0.9.11"

  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa.external_secrets_role_arn
  }

  depends_on = [module.eks, module.irsa]
}

##############################################################################
# Helm: Metrics Server (required for HPA)
##############################################################################
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"

  depends_on = [module.eks]
}

##############################################################################
# Kubernetes: App Namespace
##############################################################################
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

##############################################################################
# Kubernetes: ClusterSecretStore for External Secrets
##############################################################################
resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secretsmanager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = var.external_secrets_service_account
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

##############################################################################
# CloudWatch Dashboard — 4 Golden Signals
##############################################################################
resource "aws_cloudwatch_dashboard" "golden_signals" {
  dashboard_name = "${var.project}-${var.environment}-golden-signals"
  dashboard_body = templatefile("${path.module}/cloudwatch-dashboard.json.tpl", {
    aws_region   = var.aws_region
    cluster_name = module.eks.cluster_name
    namespace    = var.app_namespace
  })
}
