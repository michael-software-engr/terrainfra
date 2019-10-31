variable "config" { type = any }

variable "data"   { type = any }

variable "myip" {
  type = object({
    addr = string
    mask = number
  })
}

variable "mod" {
  type = object({
    associate_public_ip_address = bool
    user_data                   = string
  })
}

resource "aws_security_group" "terrainfra_svcs_instance" {
  vpc_id = var.data.vpc_id
  name = var.config.name

  ingress {
    from_port   = var.config.port.http
    to_port     = var.config.port.http
    protocol    = "tcp"
    cidr_blocks = ["${var.myip.addr}/${var.myip.mask}"]
  }

  ingress {
    from_port   = var.config.port.ssh
    to_port     = var.config.port.ssh
    protocol    = "tcp"
    cidr_blocks = ["${var.myip.addr}/${var.myip.mask}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "terrainfra_svcs_instance" {
  key_name                    = var.config.key_name
  ami                         = var.config.image_id
  instance_type               = var.config.instance_type
  vpc_security_group_ids      = [aws_security_group.terrainfra_svcs_instance.id]
  subnet_id                   = var.data.subnets.public["a"].id
  associate_public_ip_address = var.mod.associate_public_ip_address
  user_data                   = var.mod.user_data

  tags = {
    Name = var.config.name
  }
}
