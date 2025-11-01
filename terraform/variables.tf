variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "project_name" {
  type    = string
  default = "aws-3tier"
}

variable "vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.60.1.0/24", "10.60.2.0/24"]
}

variable "private_app_subnets" {
  type    = list(string)
  default = ["10.60.11.0/24", "10.60.12.0/24"]
}

variable "private_db_subnets" {
  type    = list(string)
  default = ["10.60.21.0/24", "10.60.22.0/24"]
}

variable "azs" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b"]
}

variable "frontend_instance_type" {
  type    = string
  default = "t3.small"
}

variable "backend_instance_type" {
  type    = string
  default = "t3.small"
}

# set this if you want SSH
variable "key_name" {
  type    = string
  default = "my-key-pair-2-west"
}

# if you want to force your own DB password instead of random
variable "db_password_override" {
  type      = string
  default   = ""
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "usersdb"
}
