output "proxy_public_ip" {
  value = aws_instance.public-server.public_ip
}

output "app_private_ip" {
  value = aws_instance.private-server-1.private_ip
}

output "db_private_ip" {
  value = aws_instance.private-server-2.private_ip
}

