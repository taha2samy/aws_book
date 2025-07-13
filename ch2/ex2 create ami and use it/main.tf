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
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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

resource "aws_instance" "ssh_server_with_simple_webserver" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh_key.key_name
  subnet_id              = aws_subnet.public_subnet["public_1a"].id
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]
user_data = <<-EOF
#!/bin/bash
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<html><body><h1>Hello, World!</h1></body></html>" > /var/www/html/index.html
EOF

  tags = {
    Name = "we Server"
  }
}


resource "aws_ami_from_instance" "new_ami" {
  name                    = "my-small-webserver-ami"
  source_instance_id      = aws_instance.ssh_server_with_simple_webserver.id
  snapshot_without_reboot = false

  tags = {
    Name    = "new_ami"
    Version = "1.0.0"
  }
}
resource "aws_instance" "test_server" {
  ami                    = aws_ami_from_instance.new_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh_key.key_name
  subnet_id              = aws_subnet.public_subnet["public_1a"].id
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]

  
}

