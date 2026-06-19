output "pipeline_arn" {
  description = "ARN of the Image Builder image pipeline."
  value       = aws_imagebuilder_image_pipeline.this.arn
}

output "pipeline_id" {
  description = "ID of the Image Builder image pipeline."
  value       = aws_imagebuilder_image_pipeline.this.id
}

output "image_recipe_arn" {
  description = "ARN of the Image Builder image recipe."
  value       = aws_imagebuilder_image_recipe.this.arn
}

output "infrastructure_configuration_arn" {
  description = "ARN of the Image Builder infrastructure configuration."
  value       = aws_imagebuilder_infrastructure_configuration.this.arn
}

output "distribution_configuration_arn" {
  description = "ARN of the Image Builder distribution configuration, when created."
  value       = try(aws_imagebuilder_distribution_configuration.this[0].arn, null)
}

output "component_arns" {
  description = "ARNs of custom Image Builder components created by this module."
  value       = { for key, component in aws_imagebuilder_component.this : key => component.arn }
}

output "instance_profile_name" {
  description = "IAM instance profile name used by the infrastructure configuration."
  value       = local.instance_profile_name
}

output "instance_role_arn" {
  description = "ARN of the created Image Builder EC2 instance role, when created."
  value       = try(aws_iam_role.instance[0].arn, null)
}

output "lifecycle_policy_arn" {
  description = "ARN of the Image Builder lifecycle policy, when created."
  value       = try(aws_imagebuilder_lifecycle_policy.this[0].arn, null)
}

output "lifecycle_role_arn" {
  description = "ARN of the created Image Builder lifecycle execution role, when created."
  value       = try(aws_iam_role.lifecycle[0].arn, null)
}

