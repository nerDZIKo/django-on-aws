# modules/iam/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  type        = string
}