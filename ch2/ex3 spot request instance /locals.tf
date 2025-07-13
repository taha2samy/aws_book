locals {
  network_subnets = {
    public_1a = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "${var.aws_region}a"
      private           = false
    }
    public_1b = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "${var.aws_region}b"
      private           = false
    }
  }
}