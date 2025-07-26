variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-west-1"
}


resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "my_ssh_key_of_ec2"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "ssh_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.root}/my_ssh_key_of_ec2.pem"
  file_permission = "0400"
}



resource "aws_vpc" "virtual_private_cloud" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {
  for_each = local.network_subnets

  vpc_id                  = aws_vpc.virtual_private_cloud.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.private ? false : true
  tags = {
    Name = "Public Subnet ${each.key}"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.virtual_private_cloud.id
  tags = {
    Name = "vpc-internet-gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.virtual_private_cloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "Public-Route-Table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  for_each = aws_subnet.public_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "sg_ssh" {
  vpc_id      = aws_vpc.virtual_private_cloud.id
  name        = "ssh_security_group"
  description = "Allow SSH access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ssh_server" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh_key.key_name
  subnet_id              = aws_subnet.public_subnet["public_1a"].id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
  }

  tags = {
    Name = "SSH-Server"
  }
}

resource "aws_s3_bucket" "just_example_on_s3" {
  bucket = "just-example-and-go-to-hell"

  
}
resource "aws_s3_bucket_public_access_block" "name" {
  bucket = aws_s3_bucket.just_example_on_s3.id
  ignore_public_acls = true
  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets =true

  
}
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.virtual_private_cloud.id
  service_name      = "com.amazonaws.${var.aws_region}.s3" 
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.public_route_table.id]

  tags = {
    Name = "S3-VPC-Endpoint"
  }
}

resource "aws_s3_access_point" "vpc_access" {
  bucket     = aws_s3_bucket.just_example_on_s3.id
  name       = "vpc-only-access-point"  
  
  vpc_configuration {
    vpc_id = aws_vpc.virtual_private_cloud.id
  }

  public_access_block_configuration {
    block_public_acls       = true
    ignore_public_acls      = true
    block_public_policy     = true
    restrict_public_buckets = true
  }
}
resource "aws_s3control_access_point_policy" "vpc_policy" {
  access_point_arn = aws_s3_access_point.vpc_access.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:ListBucket",
        Resource  = aws_s3_access_point.vpc_access.arn
      },
      {
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "${aws_s3_access_point.vpc_access.arn}/object/just_preifux/*"
      },
      {
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:ListBucket",
        Resource  = aws_s3_access_point.vpc_access.arn
      },
      {
        Effect    = "Deny",
        Principal = "*",
        Action = [
          "s3:GetObject"
        
        ],
        Resource = "${aws_s3_access_point.vpc_access.arn}/object/just_preifux/*"
      }

    ]
  })
}

output "s3_access_point_arn" {
  description = "The ARN of the S3 Access Point, used for policies."
  value       = aws_s3_access_point.vpc_access.arn
}
resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.just_example_on_s3.id
  key    = "just_preifux/just_file"
  source = "just_a_file.txt"
}
  
resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "ec2-s3-access-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "s3:*",
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-instance-profile"
  role = aws_iam_role.ec2_s3_role.name
}