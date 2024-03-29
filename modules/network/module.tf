variable "config" {
  type = object({
    name = string
    elb_port = object({
      listener = number
      instance = number
    })
  })
}

variable "network" {
  type = object({
    cidr_block_vpc = string
    subnets = map(any)
  })
}

variable "enable_nat" {
  type = bool
  default = true
}

variable "enable_elb" {
  type = bool
  default = true
}

variable "enable_dns_hostnames" {
  type = bool
  default = false
}

variable "enable_dns_support" {
  type = bool
  default = false
}

output "data" {
  value = {
    vpc_id = aws_vpc.terrainfra.id
    subnets = {
      priv: aws_subnet.terrainfra_subnets_priv,
      public: aws_subnet.terrainfra_subnets_public
    }

    # Because of count
    elb = aws_elb.terrainfra[0]
  }
}
