resource "aws_vpc" "private_cloud" {
  cidr_block = "10.56.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  
}

variable "subenets" {
  default = { "one":{"cidr":"10.56.1.0/24","public":true,"az":"a"}

  }
  
}
resource "aws_subnet" "subenets" {
  for_each = var.subenets
  vpc_id = aws_vpc.private_cloud.id
  availability_zone = "${var.aws_region}${each.value.az}"
  map_public_ip_on_launch = each.value.public 
  cidr_block = each.value.cidr
  tags = {
    Name= "${each.key} subnet"
  }
}

resource "tls_private_key" "key" {
  algorithm = "ED25519"
}

resource "local_file" "private_key" {
  content = tls_private_key.key.private_key_pem
  filename = "${path.root}/private.pem"
  file_permission = 0400
  
}
resource "aws_key_pair" "public_key" {
  key_name   = "terraform-generated-key"
  public_key = tls_private_key.key.public_key_openssh
}
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  vpc_id      = aws_vpc.private_cloud.id

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

  tags = {
    Name = "allow_ssh"
  }
}
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] 
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.private_cloud.id

  tags = {
    Name = "IGW"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.private_cloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}
resource "aws_route_table_association" "public_assoc" {
  for_each = { for k, v in aws_subnet.subenets : k => v if var.subenets[k].public }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}









resource "aws_security_group" "efs_access_sg" {
  name        = "efs-access-sg"
  description = "Allow NFS traffic for EFS"
  vpc_id      = aws_vpc.private_cloud.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    self = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-access-sg"
  }
}


resource "aws_efs_file_system" "web_content_efs" {
  creation_token = "web-content-efs"

  performance_mode = "generalPurpose"

  throughput_mode = "bursting"

  tags = {
    Name = "WebApp-Content"
  }
}
resource "aws_efs_mount_target" "mount_targets" {
  for_each        = aws_subnet.subenets
  file_system_id  = aws_efs_file_system.web_content_efs.id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.efs_access_sg.id]
}
resource "aws_iam_role" "ec2_efs_role" {
  name = "ec2-efs-access-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { "Service" = ["ec2.amazonaws.com"] }
      
    }]
  })
}



resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-efs-access-profile"
  role = aws_iam_role.ec2_efs_role.name
  
}

resource "aws_instance" "just_machine" {
  ami                         = data.aws_ami.amazon_linux.id 
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subenets["one"].id
  key_name                    = aws_key_pair.public_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id,aws_security_group.efs_access_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  user_data_replace_on_change = true
    user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-efs-utils
    EOF


  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_efs_file_system_policy" "force_tls_policy" {
  file_system_id = aws_efs_file_system.web_content_efs.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid"    : "EnforceInTransitEncryption",
        "Effect" : "Deny",
        "Principal" : { "AWS" : "*" },
        "Action" : "*",
        "Condition" : {
          "Bool" : {
            "aws:SecureTransport" : "false"
          }
        },
        

      },
            {
        "Sid": "AllowAccessToEC2Role",
        "Effect": "Allow",
        "Principal": {
          "AWS": aws_iam_role.ec2_efs_role.arn
        },
        "Action": [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRead",
          "elasticfilesystem:DescribeMountTargets"        
        ],
        "Resource": aws_efs_file_system.web_content_efs.arn
      }

    ]
  })
}


output "public_ip" {
  value = "ssh -i tests/private.pem ec2-user@${aws_instance.just_machine.public_dns}"
}

output "efs_id" {
  description = "The ID of the EFS File System"
  value       = aws_efs_file_system.web_content_efs.id
}
