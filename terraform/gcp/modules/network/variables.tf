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

variable "prevent_destroy" {
  type    = bool
  default = false
  description = "If true, prevents the destruction of the network resources. Useful for production environments."
  
}