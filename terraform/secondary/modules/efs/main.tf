resource "aws_security_group" "efs" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [var.main_app_security_group_id]
  }
  tags = {
    Name = "AllowPortsForEFS"
  }
}

resource "aws_efs_file_system" "efs" {
  creation_token = "my-efs"

  tags = {
    Name = "main_efs"
  }
}

resource "aws_efs_mount_target" "efs_mount" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = var.public_subnet_id
  security_groups = [aws_security_group.efs.id]
}