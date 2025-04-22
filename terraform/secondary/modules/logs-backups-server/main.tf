resource "aws_security_group" "logs_backup" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [var.main_app_security_group_id]
  }

  tags = {
    Name = "AllowPortsForLogsBackupServer"
  }
}

resource "aws_instance" "logs_backups_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.private_subnet_id
  vpc_security_group_ids = [
    aws_security_group.logs_backup.id
  ]

  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /home/ec2-user/logs
    chmod 777 /home/ec2-user/logs
  EOF

  key_name = var.ssh-key-name

  tags = {
    Name = "logs_backups_server"
  }
}