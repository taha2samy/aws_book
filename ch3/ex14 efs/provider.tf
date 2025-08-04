provider "aws" {
  region = var.aws_region
}
provider "aws" {
  alias = "just_name_region"
  region = "us-east-1"
}
