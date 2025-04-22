resource "aws_security_group" "main_app" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.main_app_access_range]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.main_app_access_range]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.main_app_access_range]
  }

  tags = {
    Name = "AllowPortsForMainApp"
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

resource "aws_instance" "cloud_gallery" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_id
  vpc_security_group_ids = [
    aws_security_group.main_app.id
  ]

  user_data = <<-EOF
    #!/bin/bash
    cat <<KEY > /ssh-key.pem
    ${var.ssh-key-value}
    KEY
    chown ec2-user:ec2-user /ssh-key.pem
    chmod 400 /ssh-key.pem
  EOF

  iam_instance_profile = aws_iam_instance_profile.cloud-gallery_profile.name

  key_name = var.ssh-key-name

  associate_public_ip_address = true

  tags = {
    Name = "Cloud Gallery"
  }
}