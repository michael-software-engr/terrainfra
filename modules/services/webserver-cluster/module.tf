variable "config" { type = any }
variable "data"   { type = any }
variable "mod"    {
  type = object({
    user_data = string
    name = string
    image_id = string
    instance_type = string
    min_size = number
    max_size = number
  })
}

resource "aws_security_group" "terrainfra_svcs_web" {
  vpc_id = var.data.vpc_id
  name = var.mod.name

  ingress {
    from_port   = var.config.elb_port.instance
    to_port     = var.config.elb_port.instance
    protocol    = "tcp"
    cidr_blocks = [
      for key, snet in var.data.subnets.public : snet.cidr_block
    ]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      for key, snet in var.data.subnets.public : snet.cidr_block
    ]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [
      for key, snet in var.data.subnets.public : snet.cidr_block
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

    # Not
    #   [for key, snet in var.data.subnets.priv : snet.cidr_block]
    # or
    #   [for key, snet in var.data.subnets.public : snet.cidr_block]
    # because you need traffic to Internet (to Ubuntu repo, GitHub, etc.) to go out.

  }
}

resource "aws_launch_configuration" "terrainfra" {
  key_name                    = var.config.key_name
  associate_public_ip_address = false
  image_id                    = var.mod.image_id
  instance_type               = var.mod.instance_type
  security_groups             = [aws_security_group.terrainfra_svcs_web.id]

  name_prefix = "${var.mod.name}-"
  # ... don't use name because it will create conflicts.
  #   Probably because of the lifecycle => create_before_destroy = true.
  # name = var.mod.name

  user_data = var.mod.user_data

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "terrainfra" {
  launch_configuration = aws_launch_configuration.terrainfra.id
  vpc_zone_identifier = [for key, snet in var.data.subnets.priv : snet.id]
  name = var.mod.name

  min_size = var.mod.min_size
  max_size = var.mod.max_size

  load_balancers    = [var.data.elb.name]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "${var.mod.name}-autoscaling-group"
    propagate_at_launch = true
  }
}
