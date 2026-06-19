module "iam_role_lambda_payload_forwarder" {
  source = "github.com/wearetechnative/terraform-aws-iam-role?ref=9229bbd0280807cbc49f194ff6d2741265dc108a"

  role_name = local.lambda_payload_forwarder
  role_path = local.lambda_payload_forwarder

  customer_managed_policies = {
    "lambda_payload_forwarder_dlq_policy" : jsondecode(data.aws_iam_policy_document.lambda_payload_forwarder_dlq_policy.json)
    "lambda_payload_forwarder_logging_policy" : jsondecode(data.aws_iam_policy_document.lambda_payload_forwarder_logging_policy.json)
    "lambda_payload_forwarder_sns_publish_policy" : jsondecode(data.aws_iam_policy_document.lambda_payload_forwarder_sns_publish_policy.json)
    "kms" : jsondecode(data.aws_iam_policy_document.kms_ep.json)
  }

  trust_relationship = {
    "lambda" : { "identifier" : "lambda.amazonaws.com", "identifier_type" : "Service", "enforce_mfa" : false, "enforce_userprincipal" : false, "external_id" : null, "prevent_account_confuseddeputy" : false },
  }

}

data "aws_iam_policy_document" "kms_ep" {
  statement {
    sid = "AllowKMSAccess"

    actions = ["kms:Decrypt",
    "kms:GenerateDataKey*"]

    resources = [var.kms_key_arn]
  }
}


data "aws_iam_policy_document" "lambda_payload_forwarder_dlq_policy" {
  statement {
    sid = "AllowDLQAccess"

    actions = ["sqs:SendMessage"]

    resources = [var.sqs_dlq_arn]
  }
}

data "aws_iam_policy_document" "lambda_payload_forwarder_logging_policy" {
  statement {
    sid = "AllowCloudWatchLogGroupCreation"

    actions = ["logs:CreateLogGroup"]

    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid = "AllowCloudWatchLogWrites"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lambda_payload_forwarder}:*"]
  }
}

data "aws_iam_policy_document" "lambda_payload_forwarder_sns_publish_policy" {
  statement {
    sid = "AllowPublishToChatbotTopic"

    actions = ["sns:Publish"]

    resources = [aws_sns_topic.alert_notifier.arn]
  }
}
