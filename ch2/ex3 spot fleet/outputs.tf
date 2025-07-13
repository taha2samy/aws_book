output "fleet_id" {
  description = "The ID of the created EC2 Fleet."
  value       = aws_ec2_fleet.my_fleet.id
}


output "ssh_key_path" {
  description = "Path to the generated SSH private key file. chmod 0400 before use."
  value       = local_file.ssh_key.filename
}

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.virtual_private_cloud.id
}
