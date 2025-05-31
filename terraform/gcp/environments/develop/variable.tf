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
  default     = "dev"
  
}
variable "default_sa_email" {
  description = "기본 서비스 계정 이메일"
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

variable "docker_image" {
  description = "Docker 이미지 이름 (예: OpenVPN)"
  type        = string

}

variable "subnet_self_link" {
  description = "서브넷의 self link"
  type        = string
  default     = ""
}

variable "use_ecr" {
  type    = bool
  default = false
}

variable "aws_region" {
  type    = string
  default = ""
}

variable "aws_access_key_id" {
  type    = string
  default = ""
}

variable "aws_secret_access_key" {
  type    = string
  default = ""
}

# 만약 SSL 인증서/HTTPS Proxy를 여전히 한 모듈에서 같이 사용하고 싶다면:

variable "domain_frontend" {
  description = "프론트엔드 도메인 (외부 HTTPS LB) 예: app.example.com"
  type        = string
}

variable "docker_image_backend_blue" {
  description = "백엔드 Blue 컨테이너 이미지 (예: gcr.io/proj/backend:blue)"
  type        = string
  default = "gcr.io/proj/backend:blue"
}

variable "docker_image_backend_green" {
  description = "백엔드 Green 컨테이너 이미지 (예: gcr.io/proj/backend:green)"
  type        = string
  default = "gcr.io/proj/backend:green"
}

variable "docker_image_front_blue" {
  description = "프론트엔드 Blue 컨테이너 이미지 (예: gcr.io/proj/frontend:blue)"
  type        = string
  default = "gcr.io/proj/frontend:blue"
}

variable "docker_image_front_green" {
  description = "프론트엔드 Green 컨테이너 이미지 (예: gcr.io/proj/frontend:green)"
  type        = string
  default = "gcr.io/proj/frontend:green"
}