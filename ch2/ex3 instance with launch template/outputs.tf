output "just_example_instance_id" {
  value = aws_instance.just_example.id
  
  description = "The ID of the EC2 instance created from the launch template."
}

output "just_example_endpoint" {
  value = aws_instance.just_example.public_ip
  
  description = "The public IP address of the EC2 instance created from the launch template."
  
}