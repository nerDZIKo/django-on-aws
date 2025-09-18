terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }

  # Backend S3 - zakomentowane dla pierwszego uruchomienia
  # backend "s3" {
  #   bucket = "twoj-terraform-state-bucket"
  #   key    = "django-app/terraform.tfstate"
  #   region = "eu-central-1"
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# VPC
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  cluster_version     = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_max_size      = var.node_max_size
  node_min_size      = var.node_min_size
}

# RDS PostgreSQL
module "rds" {
  source = "./modules/rds"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  db_instance_class      = var.db_instance_class
  db_name               = var.db_name
  db_username           = var.db_username
  allowed_security_groups = [module.eks.worker_security_group_id]
}

# ElastiCache Redis
module "elasticache" {
  source = "./modules/elasticache"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  redis_node_type         = var.redis_node_type
  allowed_security_groups = [module.eks.worker_security_group_id]
}

# S3 Buckets
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

# IAM Roles
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  oidc_issuer_url = module.eks.oidc_issuer_url
}

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.5.4"

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      serviceAccount = {
        create = false
        name   = "aws-load-balancer-controller"
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}

# Service Account dla AWS Load Balancer Controller
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam.aws_load_balancer_controller_role_arn
    }
  }

  depends_on = [module.eks]
}

# Secrets Manager secret dla DB
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-db-credentials"
  description            = "Database credentials for Django app"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = module.rds.db_username
    password = module.rds.db_password
    engine   = "postgres"
    host     = module.rds.db_endpoint
    port     = 5432
    dbname   = module.rds.db_name
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "django_app" {
  name              = "/aws/eks/${var.project_name}-${var.environment}/django"
  retention_in_days = 7
}