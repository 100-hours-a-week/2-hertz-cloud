variable "region" {
  type        = string
}

variable "env" {
  type        = string
  description = "Environment name (e.g., dev, prod)"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones to use"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDRs"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of private subnet CIDRs"
}

variable "nat_subnet_cidrs" {
  type        = list(string)
  description = "List of NAT subnet CIDRs"
}

variable "key_name" {
  type        = string
  description = "EC2 SSH 접속을 위한 key pair 이름"
}
variable "openvpn_admin_password" {
  type        = string
  description = "OpenVPN admin password"
  
}