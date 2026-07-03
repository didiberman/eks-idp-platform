output "controller_role_arn" {
  description = "IAM role ARN for the Karpenter controller"
  value       = aws_iam_role.controller.arn
}

output "interruption_queue_name" {
  description = "SQS queue name for spot interruption handling"
  value       = aws_sqs_queue.interruption.name
}

output "namespace" {
  description = "Kubernetes namespace where Karpenter is installed"
  value       = kubernetes_namespace.karpenter.metadata[0].name
}
