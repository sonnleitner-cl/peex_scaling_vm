data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
resource "aws_key_pair" "this" {
  key_name   = "deployer-key"
  public_key = file(local.key)
}

resource "aws_instance" "bastion" {
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  root_block_device {
    encrypted = true
  }
  subnet_id = aws_subnet.public["us-west-2a"].id
  tags = {
    Name = "bastion"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

resource "aws_eip" "bastion" {
}
resource "aws_security_group" "instance_sg" {
  name        = "instance_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "instance_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "instance_sg_ingress_http" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

#trivy:ignore:AVD-AWS-0107
resource "aws_vpc_security_group_ingress_rule" "instance_sg_ingress_ssh" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "instance_sg_egress" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_launch_template" "this" {
  name_prefix            = "this"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  user_data              = filebase64("${path.module}/user-data.sh")
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
    }
  }

  monitoring {
    enabled = true
  }
  metadata_options {
    http_tokens = "required"
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.Ambiente}-${var.Proyecto}-asg"
  desired_capacity    = 1
  max_size            = 8
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.app["us-west-2a"].id, aws_subnet.app["us-west-2b"].id, aws_subnet.app["us-west-2c"].id]

  health_check_type = "ELB"
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "allow_http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#trivy:ignore:AVD-AWS-0053
resource "aws_lb" "this" {
  name                       = "test-lb-tf"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.allow_http.id]
  subnets                    = [aws_subnet.public["us-west-2a"].id, aws_subnet.public["us-west-2b"].id, aws_subnet.public["us-west-2c"].id]
  drop_invalid_header_fields = true

  tags = merge(local.tags, {
    Name = "alb-${var.Ambiente}-${var.Proyecto}"
    }
  )
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_target_group" "this" {
  name     = "tf-example-lb-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_autoscaling_attachment" "this" {
  autoscaling_group_name = aws_autoscaling_group.this.id
  lb_target_group_arn    = aws_lb_target_group.this.arn
}
