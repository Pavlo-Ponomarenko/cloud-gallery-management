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

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"

  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "InternetGateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "allow_port_5000" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AllowPort5000"
  }
}

resource "aws_instance" "cloud_gallery" {
  ami           = "ami-0ecf75a98fe8519d7"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [
    aws_security_group.allow_port_5000.id
  ]

  key_name = aws_key_pair.ssh_key.key_name

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash

              yum update -y
              yum install -y git
              yum install -y python3
              yum install pip
              pip3 install flask
              git clone https://github.com/Pavlo-Ponomarenko/cloud-gallery.git
              cd cloud-gallery
              python3 -m flask --app App run --host=0.0.0.0
            EOF

  tags = {
    Name = "Cloud Gallery"
  }
}
