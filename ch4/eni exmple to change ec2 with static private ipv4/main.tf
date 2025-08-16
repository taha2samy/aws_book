resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ENI-Demo-VPC"
  }
}
data "aws_availability_zones" "AZs" {
  all_availability_zones = true
  state = "available"

}
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.AZs.names[0]
  tags = {
    Name = "Private-Subnet"
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

resource "aws_security_group" "internal_access" {
  name   = "internal-access-sg"
  vpc_id = aws_vpc.main.id

}

resource "aws_network_interface" "persistent_app_eni" {
  subnet_id       = aws_subnet.private.id
  #private_ips     = ["10.0.1.100"] 
  security_groups = [aws_security_group.internal_access.id]

  tags = {
    Name = "My-Application-ENI"
  }
}
resource "aws_instance" "app_server_v1" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.large"
  subnet_id     = aws_subnet.private.id
  security_groups = [aws_security_group.internal_access.id]


}
resource "aws_instance" "app_server_v12" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.large"
  subnet_id     = aws_subnet.private.id
  security_groups = [aws_security_group.internal_access.id]

}
resource "aws_instance" "app_server_v13" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.large"
  subnet_id     = aws_subnet.private.id
  security_groups = [aws_security_group.internal_access.id]


}

resource "aws_network_interface_attachment" "eni_attachment" {
  instance_id = aws_instance.app_server_v1.id
  network_interface_id = aws_network_interface.persistent_app_eni.id
  device_index         = 1 
  
}
