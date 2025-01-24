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

resource "aws_launch_template" "this" {
  name_prefix   = "this"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  metadata_options {
    http_tokens = "required"
  }
}

resource "aws_autoscaling_group" "this" {
  desired_capacity    = 1
  max_size            = 8
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.app["us-west-2a"].id, aws_subnet.app["us-west-2b"].id, aws_subnet.app["us-west-2c"].id]

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "this" {
  name                   = "asg-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.this.name
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
  cidr_ipv4         = aws_vpc.main.cidr_block
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
  name        = "tf-example-lb-alb-tg"
  target_type = "alb"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
}

resource "aws_autoscaling_attachment" "this" {
  autoscaling_group_name = aws_autoscaling_group.this.id
  lb_target_group_arn    = aws_lb_target_group.this.arn
}
