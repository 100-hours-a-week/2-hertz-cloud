variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "region" {
  type        = string
  description = "리전 (subnet에 적용)"
}

variable "vpc_name" {
  type        = string
  description = "VPC 이름"
}

variable "subnets" {
  description = "Subnets 리스트: name, cidr, private_ip_google_access"
  type = list(object({
    name                     = string
    cidr                     = string
    private_ip_google_access = bool
    purpose                  = optional(string)
    role                     = optional(string)
  }))
}