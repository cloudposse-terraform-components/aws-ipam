terraform {
  # >= 1.4.0 to match the module: `optional()` defaults on `pools` and the
  # `terraform_data`-backed `replace_triggered_by` guards the module relies on.
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 6.56.0 to match the module: full IPAM argument surface, plus the
      # `aws_subnet` IPAM-release-on-delete and cross-account `source_resource`
      # fixes that matter to anything consuming the pools.
      version = ">= 6.56.0"
    }
  }
}
