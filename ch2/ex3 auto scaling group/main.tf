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

resource "aws_security_group" "sg_ssh_http" {
  vpc_id      = aws_vpc.virtual_private_cloud.id
  name        = "ssh_security_group"
  description = "Allow SSH access"

    dynamic "ingress" {

    for_each = var.services
    content {
      
    
    from_port   = ingress.value.port
    to_port     = ingress.value.port
    protocol    = ingress.value.protocol_type
    cidr_blocks = ["0.0.0.0/0"]
    }
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



resource "aws_launch_template" "ec2_launch_template" {
  name_prefix   = "ec2-launch-template-"
  image_id      = data.aws_ami.latest_amazon_linux.id
  instance_type = "t2.micro"
  network_interfaces {
    subnet_id                   = aws_subnet.public_subnet["public_1a"].id
    security_groups             = [aws_security_group.sg_ssh_http.id]

  }
  key_name = aws_key_pair.ssh_key.key_name

user_data = base64encode(<<-EOF
#!/bin/bash
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<html><body><h1>Hello, World! 22</h1></body></html>" > /var/www/html/index.html
EOF
)
  tags = {
    Name = "EC2 Launch Template"
    
  }

}

variable "instance_types" {
  description = "Map of instance types and their weights for the EC2 Fleet."
  type = map(object({
    type   = string
    weight = number
  }))
  default = {
    t2_micro   = { type = "t2.micro", weight = 1 }
    t3_micro   = { type = "t3.micro", weight = 1 }
    t3a_micro  = { type = "t3a.micro", weight = 1 }
    t4g_micro  = { type = "t4g.micro", weight = 1 }
    t3a_small  = { type = "t3a.small", weight = 1 }
    t3_medium   = { type = "t3.medium", weight = 2}
  }
  
}
variable "services" {
  description = "Map of services and their configurations "
  type = map(object({
    protocol_type   = string
    protocol = string
    port = number
  }))
  default = {
    service-one = { protocol_type = "tcp", protocol = "HTTP", port = 80 }
    service-two = { protocol_type = "tcp", protocol = "HTTP", port = 8080 }
    service-three = { protocol_type = "tcp", protocol = "HTTP", port = 9000 }
  }
}

resource "aws_lb_target_group" "https_tg" {
  for_each = var.services
  name     = "https-web-tg-${each.key}"
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = aws_vpc.virtual_private_cloud.id
  health_check {
    path = "/"
    unhealthy_threshold = 2
    healthy_threshold   = 2
    timeout             = 4
    interval            = 10
    port = "traffic-port"
    protocol = "HTTP"
  }

  tags = { Name = "HTTPS-Web-TG" }
}

resource "aws_launch_template" "fleet_lt" {

  name_prefix   = "fleet-lt--"
  image_id      = data.aws_ami.latest_amazon_linux.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ssh_key.key_name

  network_interfaces {
    subnet_id                   = aws_subnet.public_subnet["public_1a"].id
    security_groups             = [aws_security_group.sg_ssh_http.id]
    associate_public_ip_address = true
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Fleet Instance"
    }
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl stop httpd
echo "Listen 8080" >> /etc/httpd/conf/httpd.conf
echo "Listen 9000" >> /etc/httpd/conf/httpd.conf
mkdir -p /var/www/html_port80
mkdir -p /var/www/html_port8080
mkdir -p /var/www/html_port9000
echo "<html><body><h1>Hello from EC2 Fleet - Web Server on Port 80!</h1><p>This is the default HTTP service.</p></body></html>" > /var/www/html_port80/index.html
echo "<html><body><h1>Hello from EC2 Fleet - Web Server on Port 8080!</h1><p>This is the service on port 8080.</p></body></html>" > /var/www/html_port8080/index.html
echo "<html><body><h1>Hello from EC2 Fleet - Web Server on Port 9000!</h1><p>This is the service on port 9000.</p></body></html>" > /var/www/html_port9000/index.html
cat <<'EOT' > /etc/httpd/conf.d/multi_port_vhosts.conf
<VirtualHost *:80>
    DocumentRoot "/var/www/html_port80"
    <Directory "/var/www/html_port80">
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/port80_error.log
    CustomLog /var/log/httpd/port80_access.log combined
</VirtualHost>
<VirtualHost *:8080>
    DocumentRoot "/var/www/html_port8080"
    <Directory "/var/www/html_port8080">
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/port8080_error.log
    CustomLog /var/log/httpd/port8080_access.log combined
</VirtualHost>
<VirtualHost *:9000>
    DocumentRoot "/var/www/html_port9000"
    <Directory "/var/www/html_port9000">
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/port9000_error.log
    CustomLog /var/log/httpd/port9000_access.log combined
</VirtualHost>
EOT
chcon -R -t httpd_sys_content_t /var/www/html_port80
chcon -R -t httpd_sys_content_t /var/www/html_port8080
chcon -R -t httpd_sys_content_t /var/www/html_port9000
systemctl start httpd
systemctl enable httpd
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --zone=public --add-port=80/tcp --permanent
    firewall-cmd --zone=public --add-port=8080/tcp --permanent
    firewall-cmd --zone=public --add-port=9000/tcp --permanent
    firewall-cmd --reload
fi
EOF
)

  tags = {
    Name = "Fleet Launch Template for "
    
  }
}

resource "aws_autoscaling_group" "just_example" {
  name_prefix = "example-asg-"
  min_size            = 2
  max_size            = 10
  desired_capacity    = 2
  health_check_type   = "ELB"
  health_check_grace_period = 60
  target_group_arns   = [for key, value in aws_lb_target_group.https_tg : value.arn] 
  mixed_instances_policy {
  instances_distribution {
      on_demand_allocation_strategy = "lowest-price"
      on_demand_base_capacity       = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy      = "lowest-price"
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.fleet_lt.id
        version            = "$Latest"
      }
      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value.type
          weighted_capacity = override.value.weight
        }
      }
    }
    
  }
}


#  Create an Application Load Balancer (ALB)
resource "aws_lb" "application_lb" {
  name               = "my-web-alb" 
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_ssh_http.id] 
  subnets            = [for s in aws_subnet.public_subnet : s.id] 

  enable_deletion_protection = false 

  tags = {
    Name = "My Application Load Balancer"
  }
}
# Create a listener for the ALB
resource "aws_lb_listener" "http_listener" {
  for_each = var.services
  load_balancer_arn = aws_lb.application_lb.arn
  port              = each.value.port
  protocol          = each.value.protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https_tg[each.key].arn 
  }
}

output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.application_lb.dns_name
  
}

resource "aws_autoscaling_policy" "scale_out_cpu_steps" {
  name                   = "scale-out-cpu-step-policy"
  autoscaling_group_name = aws_autoscaling_group.just_example.name
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"
  estimated_instance_warmup = 300
  step_adjustment {
    metric_interval_lower_bound = 50.0
    metric_interval_upper_bound = 60.0
    scaling_adjustment          = 2
  }
  step_adjustment {
    metric_interval_lower_bound = 60.0
    metric_interval_upper_bound = 80.0
    scaling_adjustment          = 4
  }
  step_adjustment {
    metric_interval_lower_bound = 80.0
    scaling_adjustment          = 6
  }
}

resource "aws_autoscaling_policy" "scale_in_cpu_steps" {
  name                   = "scale-in-cpu-step-policy"
  autoscaling_group_name = aws_autoscaling_group.just_example.name
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"
  estimated_instance_warmup               = 300
  step_adjustment {
    scaling_adjustment          = -1 # it will never scale in below min size of scaling group
    metric_interval_lower_bound = 40.0

  }
}
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm_step_out" {
  alarm_name          = "High-CPU-Utilization-Step-Scale-Out-ASG-${aws_autoscaling_group.just_example.name}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "Trigger step scaling out when CPU is 50% or higher."
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.just_example.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_out_cpu_steps.arn]
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_alarm_step_in" {
  alarm_name          = "Low-CPU-Utilization-Step-Scale-In-ASG-${aws_autoscaling_group.just_example.name}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 40
  alarm_description   = "Trigger step scaling in when CPU is 40% or lower."
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.just_example.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_in_cpu_steps.arn]
}
