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
