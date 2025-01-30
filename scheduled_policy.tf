resource "aws_autoscaling_schedule" "scale_up" {
  autoscaling_group_name = aws_autoscaling_group.this.name
  scheduled_action_name  = "scale-up-morning"
  min_size               = 2
  max_size               = 5
  desired_capacity       = 3
  recurrence             = "0 9 * * *" # 9 AM UTC
  time_zone              = "UTC"
}

resource "aws_autoscaling_schedule" "scale_down" {
  autoscaling_group_name = aws_autoscaling_group.this.name
  scheduled_action_name  = "scale-down-evening"
  min_size               = 1
  max_size               = 3
  desired_capacity       = 1
  recurrence             = "0 18 * * *" # 6 PM UTC
  time_zone              = "UTC"
}
