variable "region" { type = string }

locals {
  region = "us-west-1"

  network = {
    dev = "172.20"
    tiny = "172.21"
    lambda = "172.22"
  }
}

output "dev" {
  value = {
    cidr_block_vpc = "${local.network.dev}.0.0/16"
    subnets = {
       priv = {
        a = { az: "${var.region}a", cidr_block: "${local.network.dev}.10.0/24" }
        b = { az: "${var.region}b", cidr_block: "${local.network.dev}.20.0/24" }
      }

      public = {
        a = { az: "${var.region}a", cidr_block: "${local.network.dev}.40.240/28" }
        b = { az: "${var.region}b", cidr_block: "${local.network.dev}.80.240/28" }
      }
    }
  }
}

output "tiny" {
  value = {
    cidr_block_vpc = "${local.network.tiny}.0.0/16"
    subnets = {
       priv = {
        a = { az: "${var.region}a", cidr_block: "${local.network.tiny}.10.0/24" }
        b = { az: "${var.region}b", cidr_block: "${local.network.tiny}.20.0/24" }
      }

      public = {
        a = { az: "${var.region}a", cidr_block: "${local.network.tiny}.40.240/28" }
        b = { az: "${var.region}b", cidr_block: "${local.network.tiny}.80.240/28" }
      }
    }
  }
}

output "lambda" {
  value = {
    cidr_block_vpc = "${local.network.lambda}.0.0/16"
    subnets = {
       priv = {
        a = { az: "${var.region}a", cidr_block: "${local.network.lambda}.10.0/24" }
        b = { az: "${var.region}b", cidr_block: "${local.network.lambda}.20.0/24" }
      }

      public = {
        a = { az: "${var.region}a", cidr_block: "${local.network.lambda}.40.240/28" }
        b = { az: "${var.region}b", cidr_block: "${local.network.lambda}.80.240/28" }
      }
    }
  }
}
