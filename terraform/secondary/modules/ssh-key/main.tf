resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  filename        = "ssh-key.pem"
  content         = tls_private_key.my_key.private_key_pem
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "ssh-key"
  public_key = tls_private_key.my_key.public_key_openssh
}