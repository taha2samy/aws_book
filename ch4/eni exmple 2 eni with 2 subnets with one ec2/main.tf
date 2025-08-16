resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Multi-Subnet-EC2-VPC"
  }
}

locals {
  availability_zone = "eu-west-1a"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-Multi-ENI"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = local.availability_zone

  tags = {
    Name = "Private-Subnet-Multi-ENI"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "public_eni_sg" {
  name   = "public-eni-sg"
  vpc_id = aws_vpc.main.id

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

resource "aws_security_group" "private_eni_sg" {
  name   = "private-eni-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0    
    to_port     = 0    
    protocol    = "-1" 
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux" {
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

resource "local_file" "ssh_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.root}/my_ssh_key_of_ec2.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "my_key" {
  key_name   = "multi-eni-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_instance" "multi_homed_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.my_key.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_eni_sg.id]

  tags = {
    Name = "Multi-Homed Web Server"
  }
}

resource "aws_network_interface" "private_eni" {
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.private_eni_sg.id]
  private_ips     = ["10.0.2.100"]

  tags = {
    Name = "Private-Side-ENI"
  }
}

resource "aws_network_interface_attachment" "eni_attachment" {
  instance_id          = aws_instance.multi_homed_server.id
  network_interface_id = aws_network_interface.private_eni.id
  device_index         = 1
}

output "server_public_ip" {
  value = aws_instance.multi_homed_server.public_ip
}

output "server_private_ip_on_public_subnet" {
  value = aws_instance.multi_homed_server.private_ip
}

output "server_private_ip_on_private_subnet" {
  value = aws_network_interface.private_eni.private_ip
}

output "ssh_command" {
  value = "ssh -i my_ssh_key_of_ec2.pem ec2-user@${aws_instance.multi_homed_server.public_ip}"
}