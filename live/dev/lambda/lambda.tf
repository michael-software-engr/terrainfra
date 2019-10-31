resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  # AWSLambdaBasicExecutionRole
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

locals {
  payload = "${path.module}/payload/build/lambda_function_payload.zip"
}

variable "managed_policies" {
  default = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

resource "aws_iam_role_policy_attachment" "tc-role-policy-attach" {
  count      = "${length(var.managed_policies)}"
  policy_arn = "${element(var.managed_policies, count.index)}"
  role       = aws_iam_role.iam_for_lambda.name
}

resource "aws_lambda_function" "test_lambda" {
  filename      = local.payload
  function_name = "lambda_function_name"
  role          = "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "lambda_function_payload.handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256(local.payload)

  runtime = "nodejs8.10"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

# variable "version" {
#   type = "string"
#   default = "0.1-SNAPSHOT"
# }

# resource "aws_lambda_function" "lambda-elb-test-lambda" {
#   function_name = "lambda-elb-test"

#   s3_bucket = "lambda-elb-test"
#   s3_key    = "lambda/de/frosner/elastic-beanstalk-vs-lambda_2.12/${var.version}/elastic-beanstalk-vs-lambda_2.12-${var.version}-assembly.jar"

#   handler = "de.frosner.elbvsl.lambda.Handler"
#   runtime = "java8"

#   role = "${aws_iam_role.lambda_exec.arn}"

#   memory_size = 1024
# }

# resource "aws_iam_role" "lambda_exec" {
#   name = "lambda-elb-test_lambda"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "lambda.amazonaws.com"
#       },
#       "Effect": "Allow",
#       "Sid": ""
#     }
#   ]
# }
# EOF
# }
