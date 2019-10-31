terraform {
  required_version = ">= 0.12"

  backend "local" {
    path = "../../../state/live/dev/base/terraform.tfstate"
  }
}

provider "aws" { region = local.config.region }

module "network" {
  source = "../../config/network"
  region = local.config.region
}

module "terrainfra_dev_network" {
  source = "../../../modules/network"
  config = local.config
  network = module.network.dev
}

module "terrainfra_dev_bastion" {
  source = "../../../modules/bastion"

  config = local.config.bastion
  myip = {
    addr = local.config.myip_addr
    mask = local.config.myip_mask
  }

  data = {
    vpc_id = module.terrainfra_dev_network.data.vpc_id
    subnet_id = module.terrainfra_dev_network.data.subnets.public["a"].id
  }
}
