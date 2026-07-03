output "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.state.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.locks.name
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt Terraform state"
  value       = aws_kms_key.state.arn
}

output "backend_config" {
  description = "Copy this block into environments/*/backend.tf after bootstrap"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.state.id}"
        key            = "environments/dev/terraform.tfstate"
        region         = "${var.aws_region}"
        dynamodb_table = "${aws_dynamodb_table.locks.name}"
        encrypt        = true
        kms_key_id     = "${aws_kms_key.state.arn}"
      }
    }
  EOT
}
