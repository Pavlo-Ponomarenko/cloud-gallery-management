variable "vpc_id" {
  type = string
}

variable "ami_id" {
  type = string
  default = "ami-0ecf75a98fe8519d7"
}

variable "instance_type" {
  type = string
  default = "t2.micro"
}

variable "ssh-key-name" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "main_app_security_group_id" {
  type = string
}