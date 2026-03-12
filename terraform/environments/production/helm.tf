##############################################################################
# helm.tf — Helm and Kubernetes resources
#
# WHY THIS IS A SEPARATE FILE:
#
# The Terraform Kubernetes and Helm providers resolve their authentication
# credentials at PLAN time — not at apply time. This means on a fresh deploy
# where the EKS cluster does not yet exist, Terraform tries to connect to an
# endpoint that doesn't exist yet and fails with:
#
#   "Kubernetes cluster unreachable: the server has asked for credentials"
#
# The fix is a two-stage apply in the deploy workflow:
#
#   Stage 1 — terraform apply -target=module.vpc -target=module.eks -target=module.irsa ...
#             (AWS-only resources — no Kubernetes/Helm providers needed)
#
#   Stage 2 — terraform apply
#             (full apply now that the cluster exists and providers can auth)
#
# This file is applied in Stage 2 only.
##############################################################################

##############################################################################
# Helm: AWS Load Balancer Controller
##############################################################################
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"
  wait          = true
  wait_for_jobs = true
  timeout       = 300

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
  wait             = true
  wait_for_jobs    = true
  timeout          = 300

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa.external_secrets_role_arn
  }

  # Must wait for ALB controller webhook to be registered before ESO installs.
  # Without this, ESO install hits:
  # "no endpoints available for service aws-load-balancer-webhook-service"
  depends_on = [module.eks, module.irsa, helm_release.aws_load_balancer_controller]
}

##############################################################################
# Helm: Metrics Server (required for HPA to function)
##############################################################################
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"
  wait        = true
  timeout     = 180

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
