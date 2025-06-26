# Output values

output "public_ip" {
  value = aws_instance.exposed_instance.public_ip
}