
variable "subenets" {
  default = {
    "one" = { "cidr" = "10.56.1.0/24", "public" = true, "az" = "a" },
    "two" = { "cidr" = "10.56.2.0/24", "public" = true, "az" = "b" }
  }
}
resource "aws_vpc" "private_cloud" {
  cidr_block           = "10.56.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "MyVPC" }
}
resource "aws_subnet" "subenets" {
  for_each                = var.subenets
  vpc_id                  = aws_vpc.private_cloud.id
  availability_zone       = "${var.aws_region}${each.value.az}"
  map_public_ip_on_launch = each.value.public
  cidr_block              = each.value.cidr
  tags                    = { Name = "${each.key} subnet" }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.private_cloud.id
  tags   = { Name = "IGW" }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.private_cloud.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Public Route Table" }
}
resource "aws_route_table_association" "public_assoc" {
  for_each       = { for k, v in aws_subnet.subenets : k => v if var.subenets[k].public }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}
resource "tls_private_key" "key" {
  algorithm = "ED25519"
}
resource "local_file" "private_key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "${path.module}/private.pem"
  file_permission = "0400"
}
resource "aws_key_pair" "public_key" {
  key_name   = "terraform-generated-key"
  public_key = tls_private_key.key.public_key_openssh
}
resource "aws_security_group" "allow_ssh" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.private_cloud.id
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
  tags = { Name = "allow_ssh" }
}
resource "aws_security_group" "efs_access_sg" {
  name        = "efs-access-sg"
  description = "Allow NFS traffic for EFS"
  vpc_id      = aws_vpc.private_cloud.id
  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "efs-access-sg" }
}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_kms_key" "efs_custom_key" {
  description             = "Custom KMS key for the shared EFS"
  #deletion_window_in_days = 7
}

resource "aws_efs_file_system" "shared_efs" {
  creation_token = "shared-multi-tenant-efs"

  throughput_mode                = "provisioned"
  provisioned_throughput_in_mibps = 50

  performance_mode = "maxIO"

  encrypted  = true
  kms_key_id = aws_kms_key.efs_custom_key.arn

  lifecycle_policy {
    transition_to_ia                    = "AFTER_7_DAYS"
    transition_to_archive               =  "AFTER_14_DAYS"
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name = "Shared-EFS-For-Apps-Advanced"
  }
}
resource "aws_efs_mount_target" "mount_targets" {
  for_each        = aws_subnet.subenets
  file_system_id  = aws_efs_file_system.shared_efs.id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.efs_access_sg.id]
}

resource "aws_iam_role" "webapp_role" {
  name               = "webapp-role"
  assume_role_policy = jsonencode({ "Version" : "2012-10-17", "Statement" : [{ "Action" : "sts:AssumeRole", "Effect" : "Allow", "Principal" : { "Service" : "ec2.amazonaws.com" } }] })
}
resource "aws_iam_instance_profile" "webapp_profile" {
  name = "webapp-profile"
  role = aws_iam_role.webapp_role.name
}

resource "aws_iam_role" "analytics_role" {
  name               = "analytics-role"
  assume_role_policy = jsonencode({ "Version" : "2012-10-17", "Statement" : [{ "Action" : "sts:AssumeRole", "Effect" : "Allow", "Principal" : { "Service" : "ec2.amazonaws.com" } }] })
}
resource "aws_iam_instance_profile" "analytics_profile" {
  name = "analytics-profile"
  role = aws_iam_role.analytics_role.name
}

resource "aws_efs_access_point" "webapp_ap" {
  file_system_id = aws_efs_file_system.shared_efs.id

  root_directory {
    path = "/webapp"
    creation_info {
      owner_gid   = 1001
      owner_uid   = 1001
      permissions = "750"
    }
  }

  posix_user {
    gid = 1001
    uid = 1001
  }
  tags = { Name = "WebApp-AccessPoint" }
}

resource "aws_efs_access_point" "analytics_ap" {
  file_system_id = aws_efs_file_system.shared_efs.id

  root_directory {
    path = "/analytics"
    creation_info {
      owner_gid   = 1002
      owner_uid   = 1002
      permissions = "750"
    }
  }

  posix_user {
    gid = 1002
    uid = 1002
  }
  tags = { Name = "Analytics-AccessPoint" }
}

resource "aws_instance" "webapp_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subenets["one"].id
  key_name                    = aws_key_pair.public_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id, aws_security_group.efs_access_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.webapp_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-efs-utils
    mkdir -p /mnt/webapp
    mount -t efs -o tls,accesspoint=${aws_efs_access_point.webapp_ap.id} ${aws_efs_file_system.shared_efs.id}:/ /mnt/webapp
    echo '${aws_efs_file_system.shared_efs.id}:/ /mnt/webapp efs _netdev,tls,accesspoint=${aws_efs_access_point.webapp_ap.id} 0 0' >> /etc/fstab
  EOF

  depends_on = [aws_efs_mount_target.mount_targets]
  tags       = { Name = "WebApp-Server" }
}

resource "aws_instance" "analytics_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subenets["two"].id
  key_name                    = aws_key_pair.public_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id, aws_security_group.efs_access_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.analytics_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-efs-utils
    mkdir -p /mnt/analytics
    mount -t efs -o tls,accesspoint=${aws_efs_access_point.analytics_ap.id} ${aws_efs_file_system.shared_efs.id}:/ /mnt/analytics
    echo '${aws_efs_file_system.shared_efs.id}:/ /mnt/analytics efs _netdev,tls,accesspoint=${aws_efs_access_point.analytics_ap.id} 0 0' >> /etc/fstab
  EOF

  depends_on = [aws_efs_mount_target.mount_targets]
  tags       = { Name = "Analytics-Server" }
}

resource "aws_efs_file_system_policy" "multi_tenant_policy" {
  file_system_id = aws_efs_file_system.shared_efs.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Allow-WebApp-Through-Its-AP",
        "Effect" : "Allow",
        "Principal" : { "AWS" : aws_iam_role.webapp_role.arn },
        "Action" : "elasticfilesystem:ClientWrite",
        "Resource" : aws_efs_file_system.shared_efs.arn,
        "Condition" : {
          "StringEquals" : {
            "elasticfilesystem:AccessPointArn" : aws_efs_access_point.webapp_ap.arn
          }
        }
      },
      {
        "Sid" : "Allow-Analytics-Through-Its-AP",
        "Effect" : "Allow",
        "Principal" : { "AWS" : aws_iam_role.analytics_role.arn },
        "Action" : "elasticfilesystem:ClientWrite",
        "Resource" : aws_efs_file_system.shared_efs.arn,
        "Condition" : {
          "StringEquals" : {
            "elasticfilesystem:AccessPointArn" : aws_efs_access_point.analytics_ap.arn
          }
        }
      },
      {
        "Sid" : "Allow-Everyone-To-Mount",
        "Effect" : "Allow",
        "Principal" : { "AWS" : "*" },
        "Action" : "elasticfilesystem:ClientMount",
        "Resource" : aws_efs_file_system.shared_efs.arn
      }
    ]
  })
}

output "webapp_server_ssh" {
  value = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.webapp_server.public_dns}"
}
output "analytics_server_ssh" {
  value = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.analytics_server.public_dns}"
}
output "shared_efs_id" {
  value = aws_efs_file_system.shared_efs.id
}