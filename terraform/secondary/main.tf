module "ssh-key" {
  source = "./modules/ssh-key"
}

module "vpc" {
  source = "./modules/vpc"
  availability_zone = var.availability_zone
}

module "main_app" {
  source = "./modules/main_app"
  vpc_id = module.vpc.id
  main_app_access_range = var.main_app_access_range
  ami_id = var.ami_id
  instance_type = var.instance_type
  public_subnet_id = module.vpc.public_subnet_id
  ssh-key-name = module.ssh-key.name
  ssh-key-value = module.ssh-key.private_key
}

module "efs" {
  source = "./modules/efs"
  vpc_id = module.vpc.id
  public_subnet_id = module.vpc.public_subnet_id
  main_app_security_group_id = module.main_app.security_group_id
}

module "s3" {
  source = "./modules/s3"
}

module "logs-backups-server" {
  source = "./modules/logs-backups-server"
  vpc_id = module.vpc.id
  ami_id = var.ami_id
  instance_type = var.instance_type
  ssh-key-name = module.ssh-key.name
  main_app_security_group_id = module.main_app.security_group_id
  private_subnet_id = module.vpc.private_subnet_id
}