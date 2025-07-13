output "just_example_instance_id" {
  value = aws_spot_instance_request.just_example.id
  
  description = "The ID of the EC2 instance created from the launch template."
}

output "just_example_endpoint" {
  value = aws_spot_instance_request.just_example.public_ip
  
  description = "The public IP address of the EC2 instance created from the launch template."
  
}
output "launch_template_version" {
  value = aws_launch_template.ec2_launch_template.latest_version
  
}