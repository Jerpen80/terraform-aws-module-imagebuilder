# Terraform AWS EC2 Image Builder Module

This module creates an AWS EC2 Image Builder AMI pipeline with:

- Image Builder image recipe
- Image Builder infrastructure configuration
- Image Builder image pipeline
- Optional custom Image Builder components
- Optional AMI distribution configuration
- Optional lifecycle policy
- Optional IAM instance profile and lifecycle execution role

## Requirements

| Name | Version |
| --- | --- |
| Terraform | >= 1.3.0 |
| AWS provider | >= 5.74.0 |

## Basic Usage

```hcl
module "image_builder" {
  source = "./"

  name = "al2023-golden"

  recipe = {
    parent_image = "arn:aws:imagebuilder:eu-west-1:aws:image/amazon-linux-2023-x86/x.x.x"
    version      = "1.0.0"

    components = [
      {
        component_arn = "arn:aws:imagebuilder:eu-west-1:aws:component/update-linux/x.x.x"
      }
    ]

    block_device_mappings = [
      {
        device_name = "/dev/xvda"
        ebs = {
          delete_on_termination = true
          encrypted             = true
          volume_size           = 20
          volume_type           = "gp3"
        }
      }
    ]
  }

  infrastructure = {
    instance_types = ["t3.micro"]

    instance_metadata_options = {
      http_tokens = "required"
    }
  }

  pipeline = {
    schedule = {
      schedule_expression = "cron(0 3 ? * SUN *)"
      timezone            = "Etc/UTC"
    }
  }

  tags = {
    Project = "platform"
  }
}
```

## Custom Component Example

```hcl
module "image_builder" {
  source = "./"

  name = "al2023-custom"

  components = {
    hardening = {
      name     = "al2023-hardening"
      platform = "Linux"
      version  = "1.0.0"
      data = yamlencode({
        schemaVersion = 1.0
        phases = [{
          name = "build"
          steps = [{
            name   = "DisableRootSsh"
            action = "ExecuteBash"
            inputs = {
              commands = [
                "sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config"
              ]
            }
          }]
        }]
      })
    }
  }

  recipe = {
    parent_image = "arn:aws:imagebuilder:eu-west-1:aws:image/amazon-linux-2023-x86/x.x.x"
    version      = "1.0.0"
    components = [
      { component_key = "hardening" }
    ]
  }
}
```

## Distribution Example

```hcl
distribution_configuration = {
  distributions = [
    {
      region = "eu-west-1"
      ami_distribution_configuration = {
        name = "al2023-golden-{{ imagebuilder:buildDate }}"
        launch_permission = {
          user_ids = ["123456789012"]
        }
      }
      ssm_parameter_configurations = [
        {
          parameter_name = "/images/al2023-golden/latest"
        }
      ]
    }
  ]
}
```

## Notes

- If `create_instance_profile` is `false`, set `instance_profile_name` to an existing profile.
- AMI tags belong in `distribution_configuration.distributions[*].ami_distribution_configuration.ami_tags`.
- Recipe versions must be bumped when component data, component URI, or recipe content changes in ways that require replacement.
- The module uses `replace_triggered_by` on the pipeline for the image recipe, matching AWS provider guidance for provider versions 5.74.0 and newer.


<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.50.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_iam_role_lambda_payload_forwarder"></a> [iam\_role\_lambda\_payload\_forwarder](#module\_iam\_role\_lambda\_payload\_forwarder) | github.com/wearetechnative/terraform-aws-iam-role | 9229bbd0280807cbc49f194ff6d2741265dc108a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_imagebuilder_component.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_component) | resource |
| [aws_imagebuilder_distribution_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_distribution_configuration) | resource |
| [aws_imagebuilder_image_pipeline.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_image_pipeline) | resource |
| [aws_imagebuilder_image_recipe.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_image_recipe) | resource |
| [aws_imagebuilder_infrastructure_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_infrastructure_configuration) | resource |
| [aws_imagebuilder_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_lifecycle_policy) | resource |
| [aws_iam_policy_document.kms_ep](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_payload_forwarder_dlq_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_payload_forwarder_logging_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_payload_forwarder_sns_publish_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_components"></a> [components](#input\_components) | Custom Image Builder components to create. Reference them from recipe.components with component\_key. | <pre>map(object({<br>    name                  = string<br>    platform              = string<br>    version               = string<br>    change_description    = optional(string)<br>    data                  = optional(string)<br>    description           = optional(string)<br>    kms_key_id            = optional(string)<br>    skip_destroy          = optional(bool, false)<br>    supported_os_versions = optional(set(string))<br>    tags                  = optional(map(string), {})<br>    uri                   = optional(string)<br>  }))</pre> | `{}` | no |
| <a name="input_create_instance_profile"></a> [create\_instance\_profile](#input\_create\_instance\_profile) | Whether to create the EC2 instance role and instance profile used by Image Builder build instances. | `bool` | `true` | no |
| <a name="input_create_lifecycle_role"></a> [create\_lifecycle\_role](#input\_create\_lifecycle\_role) | Whether to create an Image Builder lifecycle execution role when lifecycle\_policy is set. | `bool` | `true` | no |
| <a name="input_distribution_configuration"></a> [distribution\_configuration](#input\_distribution\_configuration) | Optional AMI distribution configuration. | <pre>object({<br>    name        = optional(string)<br>    description = optional(string)<br>    distributions = list(object({<br>      region                     = string<br>      license_configuration_arns = optional(set(string))<br>      ami_distribution_configuration = optional(object({<br>        ami_tags           = optional(map(string), {})<br>        description        = optional(string)<br>        kms_key_id         = optional(string)<br>        name               = optional(string)<br>        target_account_ids = optional(set(string))<br>        launch_permission = optional(object({<br>          organization_arns        = optional(set(string))<br>          organizational_unit_arns = optional(set(string))<br>          user_groups              = optional(set(string))<br>          user_ids                 = optional(set(string))<br>        }))<br>      }))<br>      launch_template_configurations = optional(list(object({<br>        account_id         = optional(string)<br>        default            = optional(bool, true)<br>        launch_template_id = string<br>      })), [])<br>      s3_export_configuration = optional(object({<br>        disk_image_format = string<br>        role_name         = string<br>        s3_bucket         = string<br>        s3_prefix         = optional(string)<br>      }))<br>      ssm_parameter_configurations = optional(list(object({<br>        ami_account_id = optional(string)<br>        data_type      = optional(string, "aws:ec2:image")<br>        parameter_name = string<br>      })), [])<br>    }))<br>  })</pre> | `null` | no |
| <a name="input_infrastructure"></a> [infrastructure](#input\_infrastructure) | Image Builder infrastructure configuration. | <pre>object({<br>    name                          = optional(string)<br>    description                   = optional(string)<br>    instance_types                = optional(set(string))<br>    key_pair                      = optional(string)<br>    resource_tags                 = optional(map(string), {})<br>    security_group_ids            = optional(set(string))<br>    sns_topic_arn                 = optional(string)<br>    subnet_id                     = optional(string)<br>    terminate_instance_on_failure = optional(bool, true)<br>    instance_metadata_options = optional(object({<br>      http_put_response_hop_limit = optional(number)<br>      http_tokens                 = optional(string, "required")<br>    }))<br>    logging = optional(object({<br>      s3_bucket_name = string<br>      s3_key_prefix  = optional(string)<br>    }))<br>    placement = optional(object({<br>      availability_zone       = optional(string)<br>      host_id                 = optional(string)<br>      host_resource_group_arn = optional(string)<br>      tenancy                 = optional(string)<br>    }))<br>  })</pre> | `{}` | no |
| <a name="input_instance_profile_name"></a> [instance\_profile\_name](#input\_instance\_profile\_name) | Existing IAM instance profile name to use when create\_instance\_profile is false. If create\_instance\_profile is true and this is set, it is used as the created profile name. | `string` | `null` | no |
| <a name="input_instance_profile_permissions_boundary"></a> [instance\_profile\_permissions\_boundary](#input\_instance\_profile\_permissions\_boundary) | Permissions boundary ARN for the created Image Builder EC2 instance role. | `string` | `null` | no |
| <a name="input_instance_profile_policy_arns"></a> [instance\_profile\_policy\_arns](#input\_instance\_profile\_policy\_arns) | Additional policy ARNs to attach to the created Image Builder EC2 instance role. | `list(string)` | `[]` | no |
| <a name="input_instance_profile_role_name"></a> [instance\_profile\_role\_name](#input\_instance\_profile\_role\_name) | Name for the created Image Builder EC2 instance role. | `string` | `null` | no |
| <a name="input_lifecycle_policy"></a> [lifecycle\_policy](#input\_lifecycle\_policy) | Optional lifecycle policy for Image Builder output resources. | <pre>object({<br>    name                       = optional(string)<br>    description                = optional(string)<br>    execution_role_arn         = optional(string)<br>    resource_type              = optional(string, "AMI_IMAGE")<br>    resource_selection_tag_map = optional(map(string), {})<br>    resource_selection_recipe = optional(object({<br>      name             = string<br>      semantic_version = string<br>    }))<br>    action = object({<br>      type = string<br>      include_resources = optional(object({<br>        amis       = optional(bool)<br>        containers = optional(bool)<br>        snapshots  = optional(bool)<br>      }))<br>    })<br>    filter = object({<br>      type            = string<br>      value           = number<br>      retain_at_least = optional(number)<br>      unit            = optional(string)<br>    })<br>  })</pre> | `null` | no |
| <a name="input_lifecycle_role_name"></a> [lifecycle\_role\_name](#input\_lifecycle\_role\_name) | Name for the created Image Builder lifecycle execution role. | `string` | `null` | no |
| <a name="input_lifecycle_role_permissions_boundary"></a> [lifecycle\_role\_permissions\_boundary](#input\_lifecycle\_role\_permissions\_boundary) | Permissions boundary ARN for the created Image Builder lifecycle execution role. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name used for Image Builder resources when per-resource names are not supplied. | `string` | n/a | yes |
| <a name="input_pipeline"></a> [pipeline](#input\_pipeline) | Image pipeline configuration. | <pre>object({<br>    name                            = optional(string)<br>    description                     = optional(string)<br>    enhanced_image_metadata_enabled = optional(bool, true)<br>    execution_role                  = optional(string)<br>    status                          = optional(string, "ENABLED")<br>    image_tests_configuration = optional(object({<br>      image_tests_enabled = optional(bool, true)<br>      timeout_minutes     = optional(number, 720)<br>    }))<br>    logging_configuration = optional(object({<br>      image_log_group_name    = optional(string)<br>      pipeline_log_group_name = optional(string)<br>    }))<br>    schedule = optional(object({<br>      pipeline_execution_start_condition = optional(string, "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE")<br>      schedule_expression                = string<br>      timezone                           = optional(string)<br>    }))<br>  })</pre> | `{}` | no |
| <a name="input_recipe"></a> [recipe](#input\_recipe) | Image recipe configuration. | <pre>object({<br>    parent_image      = string<br>    version           = string<br>    name              = optional(string)<br>    ami_tags          = optional(map(string), {})<br>    description       = optional(string)<br>    user_data_base64  = optional(string)<br>    working_directory = optional(string)<br>    block_device_mappings = optional(list(object({<br>      device_name  = optional(string)<br>      no_device    = optional(bool)<br>      virtual_name = optional(string)<br>      ebs = optional(object({<br>        delete_on_termination = optional(bool)<br>        encrypted             = optional(bool)<br>        iops                  = optional(number)<br>        kms_key_id            = optional(string)<br>        snapshot_id           = optional(string)<br>        throughput            = optional(number)<br>        volume_size           = optional(number)<br>        volume_type           = optional(string)<br>      }))<br>    })), [])<br>    components = list(object({<br>      component_arn = optional(string)<br>      component_key = optional(string)<br>      parameters    = optional(map(string), {})<br>    }))<br>    systems_manager_agent = optional(object({<br>      uninstall_after_build = bool<br>    }))<br>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources managed by this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_component_arns"></a> [component\_arns](#output\_component\_arns) | ARNs of custom Image Builder components created by this module. |
| <a name="output_distribution_configuration_arn"></a> [distribution\_configuration\_arn](#output\_distribution\_configuration\_arn) | ARN of the Image Builder distribution configuration, when created. |
| <a name="output_image_recipe_arn"></a> [image\_recipe\_arn](#output\_image\_recipe\_arn) | ARN of the Image Builder image recipe. |
| <a name="output_infrastructure_configuration_arn"></a> [infrastructure\_configuration\_arn](#output\_infrastructure\_configuration\_arn) | ARN of the Image Builder infrastructure configuration. |
| <a name="output_instance_profile_name"></a> [instance\_profile\_name](#output\_instance\_profile\_name) | IAM instance profile name used by the infrastructure configuration. |
| <a name="output_instance_role_arn"></a> [instance\_role\_arn](#output\_instance\_role\_arn) | ARN of the created Image Builder EC2 instance role, when created. |
| <a name="output_lifecycle_policy_arn"></a> [lifecycle\_policy\_arn](#output\_lifecycle\_policy\_arn) | ARN of the Image Builder lifecycle policy, when created. |
| <a name="output_lifecycle_role_arn"></a> [lifecycle\_role\_arn](#output\_lifecycle\_role\_arn) | ARN of the created Image Builder lifecycle execution role, when created. |
| <a name="output_pipeline_arn"></a> [pipeline\_arn](#output\_pipeline\_arn) | ARN of the Image Builder image pipeline. |
| <a name="output_pipeline_id"></a> [pipeline\_id](#output\_pipeline\_id) | ID of the Image Builder image pipeline. |
<!-- END_TF_DOCS -->
