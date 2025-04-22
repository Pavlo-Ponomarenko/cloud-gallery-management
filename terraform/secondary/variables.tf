variable "availability_zone" {
  type = string
  default = "eu-central-1a"
}

variable "main_app_access_range" {
  type = string
  default = "10.0.0.0/16"
}

variable "ami_id" {
  type = string
  default = "ami-0ecf75a98fe8519d7"
}

variable "instance_type" {
  type = string
  default = "t2.micro"
}