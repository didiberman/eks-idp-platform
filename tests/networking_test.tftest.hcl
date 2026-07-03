mock_provider "aws" {
  alias = "aws"
}

run "networking_module_valid_inputs" {
  command = plan

  module {
    source = "./modules/networking"
  }

  variables {
    name               = "test-platform"
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    cluster_name       = "test-cluster"
    enable_flow_logs   = true
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = length(var.availability_zones) == 3
    error_message = "Test fixture must use three availability zones"
  }
}
