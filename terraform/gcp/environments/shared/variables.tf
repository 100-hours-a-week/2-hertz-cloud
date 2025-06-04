variable "dev_gcp_project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "GCP 리전"
  type        = string
  default     = "asia-east1"
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

variable "env" {
  description = "환경 이름 (예: dev, prod)"
  type        = string
  default     = "shared"
  
}
variable "default_sa_email" {
  description = "기본 서비스 계정 이메일"
  type        = string
}

variable "openvpn_admin_password" {
  description = "OpenVPN 관리자 비밀번호"
  type        = string
}

variable "ssh_private_key" {
  description = "deploy 계정에 등록할 SSH 공개 키"
  type        = string
}
variable "extra_startup_script" {
  description = "추가 사용자 정의 startup script (예: OpenVPN 등)"
  type        = string
  default     = ""
}

variable "vpn_client_cidr_blocks" {
  description = "OpenVPN 서버 또는 클라이언트 IP 대역"
  type        = list(string)
}

# variables.tf
variable "vpn_private_networks" {
  description = "VPN을 통해 접근 가능한 내부망(서브넷) CIDR 목록"
  type        = list(string)
  default     = []
}

variable "proxy_subnet_cidr" {
  
  type = string
  description = "프록시 서브넷 CIDR (예:"
  default     = "10.10.31.0/26"
}