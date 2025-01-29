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

resource "aws_launch_template" "this" {
  name_prefix            = "this"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  user_data              = filebase64("${path.module}/user-data.sh")
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  block_device_mappings {
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

resource "aws_autoscaling_policy" "simple_scaling" {
  name                   = "simple-scaling-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "low-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 20
  alarm_actions       = [aws_autoscaling_policy.simple_scaling.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
}

resource "aws_autoscaling_policy" "step_scaling" {
  name                   = "step-scaling-policy"
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "StepScaling"
  autoscaling_group_name = aws_autoscaling_group.this.name

  # Increase instances when CPU is above 75%
  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment          = 2
  }

  # Decrease instances when CPU is below 20%
  step_adjustment {
    metric_interval_upper_bound = 0
    scaling_adjustment          = -1
  }

  estimated_instance_warmup = 300
}


resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 75
  alarm_actions       = [aws_autoscaling_policy.step_scaling.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
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
  name     = "tf-example-lb-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_autoscaling_attachment" "this" {
  autoscaling_group_name = aws_autoscaling_group.this.id
  lb_target_group_arn    = aws_lb_target_group.this.arn
}
