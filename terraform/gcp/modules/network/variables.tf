variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "public_subnets" {
  type = list(object({
    name                     = string
    cidr                     = string
    private_ip_google_access = bool
    component                = string # "public"
  }))
  default = []
}

variable "private_subnets" {
  type = list(object({
    name                     = string
    cidr                     = string
    private_ip_google_access = bool
    component                = string # "private"
  }))
  default = []
}

variable "nat_subnets" {
  type = list(object({
    name                     = string
    cidr                     = string
    private_ip_google_access = bool
    component                = string # "nat"
  }))
  default = []
}
