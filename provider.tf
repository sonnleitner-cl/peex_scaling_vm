terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    encrypt      = true
    bucket       = "614031743044-aws-synack-states"
    key          = "synack/peex_scaling_vm.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
