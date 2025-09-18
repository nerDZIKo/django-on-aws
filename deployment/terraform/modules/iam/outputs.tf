# modules/iam/outputs.tf
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "django_pod_role_arn" {
  description = "ARN of the Django pod IAM role"
  value       = aws_iam_role.django_pod_role.arn
}