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
  subnet_id              = aws_subnet.public_subnet.id
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

resource "aws_ebs_volume" "general_purpose_ssd" {
  availability_zone = aws_instance.ssh_server.availability_zone
  size              = 10
  type              = "gp3"
  tags = {
    Name = "gp3-volume"
  }
}

resource "aws_ebs_volume" "provisioned_iops_ssd" {
  availability_zone = aws_instance.ssh_server.availability_zone
  size              = 20
  type              = "io2"
  iops              = 200
  tags = {
    Name = "io2-volume"
  }
}

resource "aws_ebs_volume" "throughput_optimized_hdd" {
  availability_zone = aws_instance.ssh_server.availability_zone
  size              = 500
  type              = "st1"
  tags = {
    Name = "st1-volume"
  }
}

resource "aws_ebs_volume" "cold_hdd" {
  availability_zone = aws_instance.ssh_server.availability_zone
  size              = 500
  type              = "sc1"
  tags = {
    Name = "sc1-volume"
  }
}

resource "aws_volume_attachment" "gp3_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.general_purpose_ssd.id
  instance_id = aws_instance.ssh_server.id
}

resource "aws_volume_attachment" "io2_attachment" {
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.provisioned_iops_ssd.id
  instance_id = aws_instance.ssh_server.id
}

resource "aws_volume_attachment" "st1_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.throughput_optimized_hdd.id
  instance_id = aws_instance.ssh_server.id
}

resource "aws_volume_attachment" "sc1_attachment" {
  device_name = "/dev/sdi"
  volume_id   = aws_ebs_volume.cold_hdd.id
  instance_id = aws_instance.ssh_server.id
}
