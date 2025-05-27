variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "GCP 리전"
  type        = string
  default     = "asia-northeast3"
}

variable "vpc_name" {
  description = "VPC 이름"
  type        = string
  default     = "shared-vpc"
}

variable "dev_gcp_sa_key" {
  description = "개발 환경 GCP 서비스 계정 키 (JSON 형식)"
  type        = string
  
}
variable "vpc_name" {
  type        = string
  description = "VPC 이름"
}

variable "subnets" {
  description = "서브넷 리스트"
  type = list(object({
    name                     = string
    cidr                     = string
    private_ip_google_access = bool
    purpose                  = optional(string)
    role                     = optional(string)
  }))
}