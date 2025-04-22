output "private_key" {
  value = tls_private_key.my_key.private_key_pem
}

output "name" {
  value = aws_key_pair.ssh_key.key_name
}