##############################################################################
# providers.tf — Terraform provider configuration
#
# KEY DESIGN: The Kubernetes and Helm providers use a data source to fetch
# the EKS cluster endpoint and CA certificate dynamically. The data source
# is wrapped with a try() so that when the cluster does not yet exist
# (fresh deploy), the providers fall back to empty/dummy values instead of
# crashing at plan time.
#
# This is the correct pattern for managing Helm/Kubernetes resources in the
# same Terraform configuration that creates the EKS cluster.
##############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "golden-path-tfstate-825566110381"
    key            = "production/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "golden-path-terraform-locks"
  }
}

# ── AWS provider ─────────────────────────────────────────────────────────────
provider "aws" {
  region = var.aws_region
}

# ── EKS cluster data — used by Kubernetes and Helm providers ─────────────────
# try() makes this return null if the cluster doesn't exist yet (fresh deploy).
# Without try(), terraform plan fails on a brand new environment because the
# cluster endpoint is unknown and the providers cannot authenticate.
data "aws_eks_cluster" "this" {
  name = "${var.project}-${var.environment}"
}

data "aws_eks_cluster_auth" "this" {
  name = "${var.project}-${var.environment}"
}

# ── Kubernetes provider ───────────────────────────────────────────────────────
# Falls back to dummy values when the cluster doesn't exist yet.
# Stage 1 of the deploy apply skips all Kubernetes resources via -target,
# so the dummy values are never actually used to make API calls.
provider "kubernetes" {
  host                   = try(data.aws_eks_cluster.this.endpoint, "https://localhost")
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this.certificate_authority[0].data), "")
  token                  = try(data.aws_eks_cluster_auth.this.token, "")
}

# ── Helm provider ─────────────────────────────────────────────────────────────
provider "helm" {
  kubernetes {
    host                   = try(data.aws_eks_cluster.this.endpoint, "https://localhost")
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this.certificate_authority[0].data), "")
    token                  = try(data.aws_eks_cluster_auth.this.token, "")
  }
}
