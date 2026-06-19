data "aws_partition" "current" {}

locals {
  tags = merge(var.tags, {
    ManagedBy = "Terraform"
  })

  default_instance_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  instance_policy_arns  = toset(concat(local.default_instance_policy_arns, var.instance_profile_policy_arns))
  instance_profile_name = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : var.instance_profile_name

  created_component_arns = {
    for key, component in aws_imagebuilder_component.this : key => component.arn
  }

  lifecycle_role_arn = var.create_lifecycle_role ? aws_iam_role.lifecycle[0].arn : try(var.lifecycle_policy.execution_role_arn, null)
}

resource "aws_iam_role" "instance" {
  count = var.create_instance_profile ? 1 : 0

  name        = var.instance_profile_role_name != null ? var.instance_profile_role_name : "${var.name}-imagebuilder-instance"
  description = "EC2 Image Builder instance role for ${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.${data.aws_partition.current.dns_suffix}"
      }
    }]
  })

  permissions_boundary = var.instance_profile_permissions_boundary
  tags                 = local.tags
}

resource "aws_iam_role_policy_attachment" "instance" {
  for_each = var.create_instance_profile ? local.instance_policy_arns : toset([])

  role       = aws_iam_role.instance[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = var.instance_profile_name != null ? var.instance_profile_name : "${var.name}-imagebuilder"
  role = aws_iam_role.instance[0].name
  tags = local.tags
}

resource "aws_imagebuilder_component" "this" {
  for_each = var.components

  name                  = each.value.name
  platform              = each.value.platform
  version               = each.value.version
  change_description    = each.value.change_description
  data                  = each.value.data
  description           = each.value.description
  kms_key_id            = each.value.kms_key_id
  skip_destroy          = each.value.skip_destroy
  supported_os_versions = each.value.supported_os_versions
  tags                  = merge(local.tags, each.value.tags)
  uri                   = each.value.uri
}

resource "aws_imagebuilder_image_recipe" "this" {
  name         = var.recipe.name != null ? var.recipe.name : var.name
  parent_image = var.recipe.parent_image
  version      = var.recipe.version

  ami_tags          = merge(local.tags, var.recipe.ami_tags)
  description       = var.recipe.description
  tags              = local.tags
  user_data_base64  = var.recipe.user_data_base64
  working_directory = var.recipe.working_directory

  dynamic "block_device_mapping" {
    for_each = var.recipe.block_device_mappings

    content {
      device_name  = block_device_mapping.value.device_name
      no_device    = block_device_mapping.value.no_device
      virtual_name = block_device_mapping.value.virtual_name

      dynamic "ebs" {
        for_each = block_device_mapping.value.ebs == null ? [] : [block_device_mapping.value.ebs]

        content {
          delete_on_termination = ebs.value.delete_on_termination
          encrypted             = ebs.value.encrypted
          iops                  = ebs.value.iops
          kms_key_id            = ebs.value.kms_key_id
          snapshot_id           = ebs.value.snapshot_id
          throughput            = ebs.value.throughput
          volume_size           = ebs.value.volume_size
          volume_type           = ebs.value.volume_type
        }
      }
    }
  }

  dynamic "component" {
    for_each = var.recipe.components

    content {
      component_arn = component.value.component_arn != null ? component.value.component_arn : local.created_component_arns[component.value.component_key]

      dynamic "parameter" {
        for_each = component.value.parameters

        content {
          name  = parameter.key
          value = parameter.value
        }
      }
    }
  }

  dynamic "systems_manager_agent" {
    for_each = var.recipe.systems_manager_agent == null ? [] : [var.recipe.systems_manager_agent]

    content {
      uninstall_after_build = systems_manager_agent.value.uninstall_after_build
    }
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "this" {
  name                          = var.infrastructure.name != null ? var.infrastructure.name : "${var.name}-infrastructure"
  instance_profile_name         = local.instance_profile_name
  description                   = var.infrastructure.description
  instance_types                = var.infrastructure.instance_types
  key_pair                      = var.infrastructure.key_pair
  resource_tags                 = merge(local.tags, var.infrastructure.resource_tags)
  security_group_ids            = var.infrastructure.security_group_ids
  sns_topic_arn                 = var.infrastructure.sns_topic_arn
  subnet_id                     = var.infrastructure.subnet_id
  tags                          = local.tags
  terminate_instance_on_failure = var.infrastructure.terminate_instance_on_failure

  dynamic "instance_metadata_options" {
    for_each = var.infrastructure.instance_metadata_options == null ? [] : [var.infrastructure.instance_metadata_options]

    content {
      http_put_response_hop_limit = instance_metadata_options.value.http_put_response_hop_limit
      http_tokens                 = instance_metadata_options.value.http_tokens
    }
  }

  dynamic "logging" {
    for_each = var.infrastructure.logging == null ? [] : [var.infrastructure.logging]

    content {
      s3_logs {
        s3_bucket_name = logging.value.s3_bucket_name
        s3_key_prefix  = logging.value.s3_key_prefix
      }
    }
  }

  dynamic "placement" {
    for_each = var.infrastructure.placement == null ? [] : [var.infrastructure.placement]

    content {
      availability_zone       = placement.value.availability_zone
      host_id                 = placement.value.host_id
      host_resource_group_arn = placement.value.host_resource_group_arn
      tenancy                 = placement.value.tenancy
    }
  }

  lifecycle {
    precondition {
      condition     = var.create_instance_profile || var.instance_profile_name != null
      error_message = "Set create_instance_profile = true or provide instance_profile_name."
    }
  }

  depends_on = [aws_iam_role_policy_attachment.instance]
}

resource "aws_imagebuilder_distribution_configuration" "this" {
  count = var.distribution_configuration == null ? 0 : 1

  name        = var.distribution_configuration.name != null ? var.distribution_configuration.name : "${var.name}-distribution"
  description = var.distribution_configuration.description
  tags        = local.tags

  dynamic "distribution" {
    for_each = var.distribution_configuration.distributions

    content {
      region                     = distribution.value.region
      license_configuration_arns = distribution.value.license_configuration_arns

      dynamic "ami_distribution_configuration" {
        for_each = distribution.value.ami_distribution_configuration == null ? [] : [distribution.value.ami_distribution_configuration]

        content {
          ami_tags           = merge(local.tags, ami_distribution_configuration.value.ami_tags)
          description        = ami_distribution_configuration.value.description
          kms_key_id         = ami_distribution_configuration.value.kms_key_id
          name               = ami_distribution_configuration.value.name
          target_account_ids = ami_distribution_configuration.value.target_account_ids

          dynamic "launch_permission" {
            for_each = ami_distribution_configuration.value.launch_permission == null ? [] : [ami_distribution_configuration.value.launch_permission]

            content {
              organization_arns        = launch_permission.value.organization_arns
              organizational_unit_arns = launch_permission.value.organizational_unit_arns
              user_groups              = launch_permission.value.user_groups
              user_ids                 = launch_permission.value.user_ids
            }
          }
        }
      }

      dynamic "launch_template_configuration" {
        for_each = distribution.value.launch_template_configurations

        content {
          account_id         = launch_template_configuration.value.account_id
          default            = launch_template_configuration.value.default
          launch_template_id = launch_template_configuration.value.launch_template_id
        }
      }

      dynamic "s3_export_configuration" {
        for_each = distribution.value.s3_export_configuration == null ? [] : [distribution.value.s3_export_configuration]

        content {
          disk_image_format = s3_export_configuration.value.disk_image_format
          role_name         = s3_export_configuration.value.role_name
          s3_bucket         = s3_export_configuration.value.s3_bucket
          s3_prefix         = s3_export_configuration.value.s3_prefix
        }
      }

      dynamic "ssm_parameter_configuration" {
        for_each = distribution.value.ssm_parameter_configurations

        content {
          ami_account_id = ssm_parameter_configuration.value.ami_account_id
          data_type      = ssm_parameter_configuration.value.data_type
          parameter_name = ssm_parameter_configuration.value.parameter_name
        }
      }
    }
  }
}

resource "aws_imagebuilder_image_pipeline" "this" {
  name                             = var.pipeline.name != null ? var.pipeline.name : var.name
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn
  distribution_configuration_arn   = var.distribution_configuration == null ? null : aws_imagebuilder_distribution_configuration.this[0].arn
  description                      = var.pipeline.description
  enhanced_image_metadata_enabled  = var.pipeline.enhanced_image_metadata_enabled
  execution_role                   = var.pipeline.execution_role
  status                           = var.pipeline.status
  tags                             = local.tags

  dynamic "image_tests_configuration" {
    for_each = var.pipeline.image_tests_configuration == null ? [] : [var.pipeline.image_tests_configuration]

    content {
      image_tests_enabled = image_tests_configuration.value.image_tests_enabled
      timeout_minutes     = image_tests_configuration.value.timeout_minutes
    }
  }

  dynamic "logging_configuration" {
    for_each = var.pipeline.logging_configuration == null ? [] : [var.pipeline.logging_configuration]

    content {
      image_log_group_name    = logging_configuration.value.image_log_group_name
      pipeline_log_group_name = logging_configuration.value.pipeline_log_group_name
    }
  }

  dynamic "schedule" {
    for_each = var.pipeline.schedule == null ? [] : [var.pipeline.schedule]

    content {
      pipeline_execution_start_condition = schedule.value.pipeline_execution_start_condition
      schedule_expression                = schedule.value.schedule_expression
      timezone                           = schedule.value.timezone
    }
  }

  lifecycle {
    replace_triggered_by = [
      aws_imagebuilder_image_recipe.this
    ]
  }
}

resource "aws_iam_role" "lifecycle" {
  count = var.lifecycle_policy != null && var.create_lifecycle_role ? 1 : 0

  name        = var.lifecycle_role_name != null ? var.lifecycle_role_name : "${var.name}-imagebuilder-lifecycle"
  description = "EC2 Image Builder lifecycle execution role for ${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "imagebuilder.${data.aws_partition.current.dns_suffix}"
      }
    }]
  })

  permissions_boundary = var.lifecycle_role_permissions_boundary
  tags                 = local.tags
}

resource "aws_iam_role_policy_attachment" "lifecycle" {
  count = var.lifecycle_policy != null && var.create_lifecycle_role ? 1 : 0

  role       = aws_iam_role.lifecycle[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/EC2ImageBuilderLifecycleExecutionPolicy"
}

resource "aws_imagebuilder_lifecycle_policy" "this" {
  count = var.lifecycle_policy == null ? 0 : 1

  name           = var.lifecycle_policy.name != null ? var.lifecycle_policy.name : "${var.name}-lifecycle"
  description    = var.lifecycle_policy.description
  execution_role = local.lifecycle_role_arn
  resource_type  = var.lifecycle_policy.resource_type
  tags           = local.tags

  policy_detail {
    action {
      type = var.lifecycle_policy.action.type

      dynamic "include_resources" {
        for_each = var.lifecycle_policy.action.include_resources == null ? [] : [var.lifecycle_policy.action.include_resources]

        content {
          amis       = include_resources.value.amis
          containers = include_resources.value.containers
          snapshots  = include_resources.value.snapshots
        }
      }
    }

    filter {
      type            = var.lifecycle_policy.filter.type
      value           = var.lifecycle_policy.filter.value
      retain_at_least = var.lifecycle_policy.filter.retain_at_least
      unit            = var.lifecycle_policy.filter.unit
    }
  }

  resource_selection {
    tag_map = var.lifecycle_policy.resource_selection_tag_map

    dynamic "recipe" {
      for_each = var.lifecycle_policy.resource_selection_recipe == null ? [] : [var.lifecycle_policy.resource_selection_recipe]

      content {
        name             = recipe.value.name
        semantic_version = recipe.value.semantic_version
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.create_lifecycle_role || try(var.lifecycle_policy.execution_role_arn, null) != null
      error_message = "Set create_lifecycle_role = true or provide lifecycle_policy.execution_role_arn."
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lifecycle]
}

