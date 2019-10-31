locals {
  key_name = "default"
  name = "terrainfra-dev"
  region = "us-west-1"

  default_image_id = "ami-08fd8ae3806f09a08" # US West Ubuntu 18 AMI
  default_instance_type = "t2.nano"

  ssh_port = 22
  http_port = 80
}

output "key_name"      { value = local.key_name }
output "name"          { value = local.name }
output "region"        { value = local.region }
output "image_id"      { value = local.default_image_id }
output "instance_type" { value = local.default_instance_type }

output "bastion" {
  value = {
    key_name = local.key_name
    name = local.name
    ssh_ingress_port = local.ssh_port
    image_id = local.default_image_id
    instance_type = local.default_instance_type
  }
}

output "elb_port" {
  value = {
    listener = local.http_port
    instance = 8080
  }
}

output "default" {
  value = {
    image_id = local.default_image_id
    instance_type = local.default_instance_type
  }
}

output "port" {
  value = {
    ssh = local.ssh_port
    http = local.http_port
  }
}
