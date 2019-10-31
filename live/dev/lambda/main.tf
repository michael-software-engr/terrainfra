terraform {
  required_version = ">= 0.12"

  backend "local" {
    path = "../../../state/live/dev/lambda/terraform.tfstate"
  }
}

provider "aws" { region = local.config.region }

# variable "dev_lambda" {
#   type = object({
#     do_db_stuff = string
#     db_name = string
#     deploy_user = string
#     db_password = string
#   })
# }

# module "network" {
#   source = "../../config/network"
#   region = local.config.region
# }

# module "terrainfra_dev_lambda_network" {
#   source = "../../../modules/network"
#   config = local.config
#   network = module.network.lambda
#   enable_nat = false
#   enable_elb = false
#   enable_dns_hostnames = true
#   enable_dns_support = true
# }

# module "terrainfra_dev_lambda_postgres" {
#   source = "../../../modules/services/db/postgres"

#   config = local.config
#   data = module.terrainfra_dev_lambda_network.data

#   mod = {
#     name = var.dev_lambda.db_name
#     username = var.dev_lambda.deploy_user
#     password = var.dev_lambda.db_password

#     postgres_port = 5432
#   }
# }

# module "terrainfra_dev_lambda_instance" {
#   source = "../../../modules/services/instance"
#   config = local.config
#   data = module.terrainfra_dev_lambda_network.data
#   myip = {
#     addr = local.config.myip_addr
#     mask = local.config.myip_mask
#   }
#   mod = {
#     associate_public_ip_address = true
#     user_data = templatefile(
#       "${path.module}/user_data.tmpl.sh", {
#         tf_ssh_ingress_port = local.config.port.ssh

#         tf_http_port = 8080
#         # tf_http_port = local.config.port.http

#         tf_do_db_stuff = var.dev_lambda.do_db_stuff

#         # endpoint - The connection endpoint in address:port format.
#         # url: {{envOr "DATABASE_URL" "postgres://postgres:postgres@127.0.0.1:5432/awsexample_production?sslmode=disable"}}
#         # "postgres://YourUserName:YourPassword@YourHost:5432/YourDatabase";
#         tf_database_url = join("", [
#           "postgres://",
#           var.dev_lambda.deploy_user,
#           ":",
#           var.dev_lambda.db_password,
#           "@",
#           module.terrainfra_dev_lambda_postgres.data.endpoint,
#           "/",
#           var.dev_lambda.db_name,
#           "?sslmode=disable"
#         ])
#       }
#     )
#   }
# }
