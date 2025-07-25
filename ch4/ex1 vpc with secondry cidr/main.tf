
resource "aws_vpc" "vpc_without_secondary" {
  cidr_block = "10.0.0.0/16" 
  tags = {
    Name = "vpc_without-secondary-correct"
  }
}

resource "aws_vpc" "vpc_with_secondary" {
  cidr_block = "10.1.0.0/16" 
  tags = {
    Name = "vpc-primary-secondary-correct"
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr" {
  vpc_id     = aws_vpc.vpc_with_secondary.id
  cidr_block = "10.2.0.0/16" 
  }

resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr_another" {
  vpc_id     = aws_vpc.vpc_with_secondary.id
  cidr_block = "10.3.0.0/24" 
}

output "vpc_id_with_secondary_cidr" {
  value       = aws_vpc.vpc_with_secondary.id
  description = "The ID of the VPC with associated secondary CIDR blocks."
}

output "vpc_primary_cidr" {
  value       = aws_vpc.vpc_with_secondary.cidr_block
  description = "The primary CIDR block of the VPC."
}

output "vpc_secondary_cidr_1" {
  value = aws_vpc_ipv4_cidr_block_association.secondary_cidr.cidr_block
  description = "The first associated secondary CIDR block."
}

output "vpc_secondary_cidr_2" {
  value = aws_vpc_ipv4_cidr_block_association.secondary_cidr.cidr_block
  description = "The second associated secondary CIDR block."
}