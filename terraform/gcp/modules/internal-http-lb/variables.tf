variable "region" {
  description = "GCP 리전"
  type        = string
}

variable "vpc_self_link" {
  description = "VPC self link"
  type        = string
}

variable "subnet_self_link" {
  description = "백엔드가 속한 서브넷 self_link"
  type        = string
}

variable "backend_name_prefix" {
  description = "Internal LB 이름 접두어 (예: \"backend-internal-lb\")"
  type        = string
}

variable "backends" {
  description = <<EOF
백엔드 인스턴스 그룹 목록 (object list). 각 객체는 다음 필드를 포함:
  - instance_group  : string (MIG self_link)  
  - balancing_mode  : optional(string) (기본 "UTILIZATION")  
  - capacity_scaler : optional(number) (기본 1.0)  
EOF
  type = list(object({
    instance_group  = string
    balancing_mode  = optional(string, "UTILIZATION")
    capacity_scaler = optional(number, 1.0)
  }))
}

variable "backend_hc_port" {
  description = "HTTP Health Check Port (예: 8080)"
  type        = number
  default     = 8080
}

variable "backend_timeout_sec" {
  description = "Backend Service Timeout (초)"
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "Health Check 요청 Path (예: \"/health\")"
  type        = string
  default     = "/health"
}

variable "port" {
  description = "Internal Forwarding Rule Port (예: \"8080\")"
  type        = string
  default     = "8080"
}

variable "ip_prefix_length" {
  description = "Internal LB 사설 IP Prefix 길이 (예: /28)"
  type        = number
  default     = 28
}


