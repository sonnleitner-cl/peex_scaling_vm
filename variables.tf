variable "cidr" {
  default = "10.0.0.0/16"
}
variable "Ambiente" {
  default = "devel"
}
variable "Proyecto" {
  default = "devops"
}
variable "Subproyecto" {
  default = "general"
}
locals {
  tags = {
    Ambiente    = var.Ambiente
    Proyecto    = var.Proyecto
    Subproyecto = var.Subproyecto
  }
  flowlog-tags = {
    Ambiente    = var.Ambiente
    Proyecto    = var.Proyecto
    Subproyecto = var.Subproyecto
    FlowLog     = var.FlowLog
  }
  key = var.key
}
variable "FlowLog" {
  default = "ALL"
}
variable "subnet_numbers" {
  description = "Map from availability zone to the number that should be used for each availability zone's subnet"
  default = {
    us-west-2a = 1
    us-west-2b = 2
    us-west-2c = 3
  }
}
variable "key" {
  description = "Public SSH Key's path."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
