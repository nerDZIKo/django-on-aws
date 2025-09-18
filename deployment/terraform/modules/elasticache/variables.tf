# modules/elasticache/variables.tf

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ElastiCache"
  type        = list(string)
}

variable "redis_node_type" {
  description = "The instance type for ElastiCache nodes."
  type        = string
}

variable "redis_cluster_size" {
  description = "The number of nodes in the ElastiCache cluster."
  type        = number
}

variable "redis_engine_version" {
  description = "The version of the Redis engine."
  type        = string
}

variable "parameter_group_name" {
  description = "The name of the parameter group to associate with the ElastiCache cluster."
  type        = string
}

variable "security_group_ids" {
  description = "The security groups to associate with the ElastiCache cluster."
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "List of security group IDs allowed to access ElastiCache."
  type        = list(string)
}