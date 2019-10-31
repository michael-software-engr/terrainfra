module "dev_config" { source = "../../config/dev" }

variable "allow_all" {
  type = bool
  description = "TODO: if false, only allow SSH and HTTP traffic from own IP. If true, TODO."
  default = false
}

variable "myip_mask" {
  type = number
  default = 32
  description = "The size of the bit mask (n.n.n.n/myip_mask)."
}

data "external" "myip_addr" {
  count = var.allow_all ? file("ERROR: TODO, allow_all traffic.") : 1
  program = ["${path.module}/../../../tools/own-ip.sh"]
}

locals {
  config = merge(module.dev_config, {
    myip_addr = data.external.myip_addr[0].result.myip_addr
    myip_mask = var.myip_mask
    name = "${module.dev_config.name}-lambda"
    instance_type = module.dev_config.default.instance_type

    port = merge(module.dev_config.port, {
      ssh = 22
      http = 8080
    })
  })
}
