output "endpoint_ssh_server" {
  value       = aws_instance.ssh_server.public_ip
  description = "Public IP of the SSH server"
}

output "public_dns" {
  value       = aws_instance.ssh_server.public_dns
  description = "Public DNS of the SSH server"
}
output "ssh_command" {
  value       = "ssh -i ${local_file.ssh_key.filename} ec2-user@${aws_instance.ssh_server.public_ip}"
  description = "SSH command to connect to the server"
  
}