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
  cidr_block              = "10.0.0.0/24"
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

resource "aws_security_group" "main_app" {
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
    Name = "AllowPortsForMainApp"
  }
}

resource "aws_security_group" "efs" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [aws_security_group.main_app.id]
  }
  tags = {
    Name = "AllowPortsForEFS"
  }
}

resource "aws_iam_role" "app_role" {
  name = "cloud-gallery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "cloudwatch-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:CreateLogGroup",
        "logs:CreateLogStream"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "s3_read_policy" {
  name = "s3-read-only-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::images-cloud-storage",
          "arn:aws:s3:::images-cloud-storage/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "efs_mount_policy" {
  name = "efs_mount_policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_metadata_access_policy" {
  name = "ec2_metadata_access_policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cloud-gallery_profile" {
  name = "cloud-gallery-instance-profile"
  role = aws_iam_role.app_role.name
}

resource "aws_efs_file_system" "efs" {
  creation_token = "my-efs"

  tags = {
    Name = "main_efs"
  }
}

resource "aws_efs_mount_target" "efs_mount" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_instance" "cloud_gallery" {
  ami           = "ami-0ecf75a98fe8519d7"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [
    aws_security_group.main_app.id
  ]

  user_data = <<-EOF
    #!/bin/bash
    cat <<KEY > /ssh-key.pem
    ${tls_private_key.my_key.private_key_pem}
    KEY
    chown ec2-user:ec2-user /ssh-key.pem
    chmod 400 /ssh-key.pem
  EOF

  iam_instance_profile = aws_iam_instance_profile.cloud-gallery_profile.name

  key_name = aws_key_pair.ssh_key.key_name

  associate_public_ip_address = true

  tags = {
    Name = "Cloud Gallery"
  }
}

resource "aws_s3_bucket" "gallery_storage_bucket" {
  bucket = "images-cloud-storage"
  force_destroy = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "PrivateSubnet"
  }
}

resource "aws_eip" "nat_eip" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.private_subnet.id

  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "PrivateRouteTable"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "logs_backup" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.main_app.id]
  }

  tags = {
    Name = "AllowPortsForLogsBackupServer"
  }
}

resource "aws_instance" "logs_backups_server" {
  ami           = "ami-0ecf75a98fe8519d7"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id
  vpc_security_group_ids = [
    aws_security_group.logs_backup.id
  ]

  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /home/ec2-user/logs
    chmod 777 /home/ec2-user/logs
  EOF

  key_name = aws_key_pair.ssh_key.key_name

  tags = {
    Name = "logs_backups_server"
  }
}