terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.74.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "image_builder" {
  source = "../.."

  name = "al2023-golden"

  recipe = {
    parent_image = "arn:aws:imagebuilder:${var.region}:aws:image/amazon-linux-2023-x86/x.x.x"
    version      = "1.0.0"

    components = [
      {
        component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/update-linux/x.x.x"
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
    Project = "image-builder"
  }
}

output "pipeline_arn" {
  value = module.image_builder.pipeline_arn
}

