variable "name" {
  description = "Base name used for Image Builder resources when per-resource names are not supplied."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources managed by this module."
  type        = map(string)
  default     = {}
}

variable "create_instance_profile" {
  description = "Whether to create the EC2 instance role and instance profile used by Image Builder build instances."
  type        = bool
  default     = true
}

variable "instance_profile_name" {
  description = "Existing IAM instance profile name to use when create_instance_profile is false. If create_instance_profile is true and this is set, it is used as the created profile name."
  type        = string
  default     = null
}

variable "instance_profile_role_name" {
  description = "Name for the created Image Builder EC2 instance role."
  type        = string
  default     = null
}

variable "instance_profile_policy_arns" {
  description = "Additional policy ARNs to attach to the created Image Builder EC2 instance role."
  type        = list(string)
  default     = []
}

variable "instance_profile_permissions_boundary" {
  description = "Permissions boundary ARN for the created Image Builder EC2 instance role."
  type        = string
  default     = null
}

variable "components" {
  description = "Custom Image Builder components to create. Reference them from recipe.components with component_key."
  type = map(object({
    name                  = string
    platform              = string
    version               = string
    change_description    = optional(string)
    data                  = optional(string)
    description           = optional(string)
    kms_key_id            = optional(string)
    skip_destroy          = optional(bool, false)
    supported_os_versions = optional(set(string))
    tags                  = optional(map(string), {})
    uri                   = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for component in values(var.components) :
      (component.data != null && component.uri == null) || (component.data == null && component.uri != null)
    ])
    error_message = "Each component must set exactly one of data or uri."
  }
}

variable "recipe" {
  description = "Image recipe configuration."
  type = object({
    parent_image      = string
    version           = string
    name              = optional(string)
    description       = optional(string)
    user_data_base64  = optional(string)
    working_directory = optional(string)
    block_device_mappings = optional(list(object({
      device_name  = optional(string)
      no_device    = optional(bool)
      virtual_name = optional(string)
      ebs = optional(object({
        delete_on_termination = optional(bool)
        encrypted             = optional(bool)
        iops                  = optional(number)
        kms_key_id            = optional(string)
        snapshot_id           = optional(string)
        throughput            = optional(number)
        volume_size           = optional(number)
        volume_type           = optional(string)
      }))
    })), [])
    components = list(object({
      component_arn = optional(string)
      component_key = optional(string)
      parameters    = optional(map(string), {})
    }))
    systems_manager_agent = optional(object({
      uninstall_after_build = bool
    }))
  })

  validation {
    condition = alltrue([
      for component in var.recipe.components :
      (component.component_arn != null && component.component_key == null) || (component.component_arn == null && component.component_key != null)
    ])
    error_message = "Each recipe component must set exactly one of component_arn or component_key."
  }

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.recipe.version))
    error_message = "recipe.version must use semantic version format major.minor.patch, for example 1.0.0."
  }
}

variable "infrastructure" {
  description = "Image Builder infrastructure configuration."
  type = object({
    name                          = optional(string)
    description                   = optional(string)
    instance_types                = optional(set(string))
    key_pair                      = optional(string)
    resource_tags                 = optional(map(string), {})
    security_group_ids            = optional(set(string))
    sns_topic_arn                 = optional(string)
    subnet_id                     = optional(string)
    terminate_instance_on_failure = optional(bool, true)
    instance_metadata_options = optional(object({
      http_put_response_hop_limit = optional(number)
      http_tokens                 = optional(string, "required")
    }))
    logging = optional(object({
      s3_bucket_name = string
      s3_key_prefix  = optional(string)
    }))
    placement = optional(object({
      availability_zone       = optional(string)
      host_id                 = optional(string)
      host_resource_group_arn = optional(string)
      tenancy                 = optional(string)
    }))
  })
  default = {}
}

variable "distribution_configuration" {
  description = "Optional AMI distribution configuration."
  type = object({
    name        = optional(string)
    description = optional(string)
    distributions = list(object({
      region                     = string
      license_configuration_arns = optional(set(string))
      ami_distribution_configuration = optional(object({
        ami_tags           = optional(map(string), {})
        description        = optional(string)
        kms_key_id         = optional(string)
        name               = optional(string)
        target_account_ids = optional(set(string))
        launch_permission = optional(object({
          organization_arns        = optional(set(string))
          organizational_unit_arns = optional(set(string))
          user_groups              = optional(set(string))
          user_ids                 = optional(set(string))
        }))
      }))
      launch_template_configurations = optional(list(object({
        account_id         = optional(string)
        default            = optional(bool, true)
        launch_template_id = string
      })), [])
      s3_export_configuration = optional(object({
        disk_image_format = string
        role_name         = string
        s3_bucket         = string
        s3_prefix         = optional(string)
      }))
      ssm_parameter_configurations = optional(list(object({
        ami_account_id = optional(string)
        data_type      = optional(string, "aws:ec2:image")
        parameter_name = string
      })), [])
    }))
  })
  default = null
}

variable "pipeline" {
  description = "Image pipeline configuration."
  type = object({
    name                            = optional(string)
    description                     = optional(string)
    enhanced_image_metadata_enabled = optional(bool, true)
    execution_role                  = optional(string)
    status                          = optional(string, "ENABLED")
    image_tests_configuration = optional(object({
      image_tests_enabled = optional(bool, true)
      timeout_minutes     = optional(number, 720)
    }))
    schedule = optional(object({
      pipeline_execution_start_condition = optional(string, "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE")
      schedule_expression                = string
      timezone                           = optional(string)
    }))
  })
  default = {}

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.pipeline.status)
    error_message = "pipeline.status must be ENABLED or DISABLED."
  }
}

variable "create_lifecycle_role" {
  description = "Whether to create an Image Builder lifecycle execution role when lifecycle_policy is set."
  type        = bool
  default     = true
}

variable "lifecycle_role_name" {
  description = "Name for the created Image Builder lifecycle execution role."
  type        = string
  default     = null
}

variable "lifecycle_role_permissions_boundary" {
  description = "Permissions boundary ARN for the created Image Builder lifecycle execution role."
  type        = string
  default     = null
}

variable "lifecycle_policy" {
  description = "Optional lifecycle policy for Image Builder output resources."
  type = object({
    name                       = optional(string)
    description                = optional(string)
    execution_role_arn         = optional(string)
    resource_type              = optional(string, "AMI_IMAGE")
    resource_selection_tag_map = optional(map(string), {})
    resource_selection_recipe = optional(object({
      name             = string
      semantic_version = string
    }))
    action = object({
      type = string
      include_resources = optional(object({
        amis       = optional(bool)
        containers = optional(bool)
        snapshots  = optional(bool)
      }))
    })
    filter = object({
      type            = string
      value           = number
      retain_at_least = optional(number)
      unit            = optional(string)
    })
  })
  default = null

  validation {
    condition     = var.lifecycle_policy == null || contains(["AMI_IMAGE", "CONTAINER_IMAGE"], var.lifecycle_policy.resource_type)
    error_message = "lifecycle_policy.resource_type must be AMI_IMAGE or CONTAINER_IMAGE."
  }

  validation {
    condition     = var.lifecycle_policy == null || contains(["DELETE", "DEPRECATE", "DISABLE"], var.lifecycle_policy.action.type)
    error_message = "lifecycle_policy.action.type must be DELETE, DEPRECATE, or DISABLE."
  }

  validation {
    condition     = var.lifecycle_policy == null || contains(["AGE", "COUNT"], var.lifecycle_policy.filter.type)
    error_message = "lifecycle_policy.filter.type must be AGE or COUNT."
  }
}
