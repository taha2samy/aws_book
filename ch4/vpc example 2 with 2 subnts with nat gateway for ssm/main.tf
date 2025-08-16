resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.15.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC-A"
  }
}
data "aws_availability_zones" "AZs" {
  all_availability_zones = true
  state                  = "available"

}
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = cidrsubnet(aws_vpc.vpc_a.cidr_block, 8, 0)
  availability_zone       = data.aws_availability_zones.AZs.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-Subnet-A"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = cidrsubnet(aws_vpc.vpc_a.cidr_block, 8, 1)
  availability_zone = data.aws_availability_zones.AZs.names[0]
  tags = {
    Name = "Private-Subnet-A"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_a.id

  tags = {
    Name = "VPC-A-IGW"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_a.id


  route {

    cidr_block = "0.0.0.0/0"


    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public-Route-Table"
  }
}
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "VPC-A-EIP"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name = "VPC-A-NAT-GW"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "Private-Route-Table"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}



data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
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


resource "aws_security_group" "sg_ssh" {
  vpc_id      = aws_vpc.vpc_a.id
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


resource "aws_instance" "bastion_hosting" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh_key.key_name
  subnet_id              = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  tags = {
    Name = "bastion hosting"
  }
}


resource "aws_instance" "private_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh_key.key_name
  subnet_id              = aws_subnet.private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  tags = {
    Name = "private instance"
  }
}

output "bastion_public_ip" {
  description = "The Public IP address of the Bastion Host."
  value       = aws_instance.bastion_hosting.public_ip
}

output "private_instance_private_ip" {
  description = "The Private IP address of the Private Instance."
  value       = aws_instance.private_instance.private_ip
}

output "ssh_private_key_path" {
  description = "Path to the generated private key file (.pem)."
  value       = local_file.ssh_key.filename
}

output "command_ssh_to_bastion" {
  description = "Command to SSH into the Bastion Host."
  value       = "ssh -i ${local_file.ssh_key.filename} ec2-user@${aws_instance.bastion_hosting.public_ip}"
}

output "command_ssh_tunnel_to_private_instance" {
  description = "Command to create an SSH tunnel to the private instance through the Bastion."
  value       = "ssh -i ${local_file.ssh_key.filename} -N -L 2222:${aws_instance.private_instance.private_ip}:22 ec2-user@${aws_instance.bastion_hosting.public_ip}"
}

output "private_instance_id" {
  description = "The Instance ID of the Private Instance."
  value       = aws_instance.private_instance.id
}

output "command_ssm_session_to_private_instance" {
  description = "Command to start an SSM session with the private instance."
  value       = "aws ssm start-session --target ${aws_instance.private_instance.id}"
}

output "command_ssm_session_to_bastion" {
  description = "Command to start an SSM session with the bastion host."
  value       = "aws ssm start-session --target ${aws_instance.bastion_hosting.id}"
}