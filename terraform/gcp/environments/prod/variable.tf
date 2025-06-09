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
  default     = "prod"
  
}
variable "default_sa_email" {
  description = "기본 서비스 계정 이메일"
  type        = string
}


variable "deploy_ssh_public_key" {
  description = "deploy 계정에 등록할 SSH 공개 키"
  type        = string
}
variable "ssh_private_key" {
  description = "deploy private 키"
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
  default = "969400486509.dkr.ecr.ap-northeast-2.amazonaws.com/tuning-springboot:develop-latest"
}

variable "docker_image_backend_green" {
  description = "백엔드 Green 컨테이너 이미지 (예: gcr.io/proj/backend:green)"
  type        = string
  default = "969400486509.dkr.ecr.ap-northeast-2.amazonaws.com/tuning-springboot:develop-latest"
}

variable "docker_image_front_blue" {
  description = "프론트엔드 Blue 컨테이너 이미지 (예: gcr.io/proj/frontend:blue)"
  type        = string
  default = "969400486509.dkr.ecr.ap-northeast-2.amazonaws.com/tuning-nextjs:develop-latest"
}

variable "docker_image_front_green" {
  description = "프론트엔드 Green 컨테이너 이미지 (예: gcr.io/proj/frontend:green)"
  type        = string
  default = "969400486509.dkr.ecr.ap-northeast-2.amazonaws.com/tuning-nextjs:develop-latest"
}

variable "proxy_subnet_cidr" {
  
  type = string
  description = "프록시 서브넷 CIDR (예:"
  default     = "10.10.31.0/26"
}


# Blue/Green 배포 제어 변수
variable "active_deployment" {
  description = "Currently active deployment color"
  type        = string
  default     = "blue"
  
  validation {
    condition     = contains(["blue", "green"], var.active_deployment)
    error_message = "Active deployment must be either 'blue' or 'green'."
  }
}

variable "traffic_weight_blue_frontend" {
  description = "Traffic weight for blue deployment (0-100)"
  type        = number
  default     = 100
  
  validation {
    condition     = var.traffic_weight_blue_frontend >= 0 && var.traffic_weight_blue_frontend <= 100
    error_message = "Traffic weight must be between 0 and 100."
  }
}

variable "traffic_weight_blue_backend" {
  description = "Traffic weight for blue deployment (0-100)"
  type        = number
  default     = 100
  
  validation {
    condition     = var.traffic_weight_blue_backend >= 0 && var.traffic_weight_blue_backend <= 100
    error_message = "Traffic weight must be between 0 and 100."
  }
}

variable "traffic_weight_green_frontend" {
  description = "Traffic weight for green deployment (0-100)"
  type        = number
  default     = 0
  
  validation {
    condition     = var.traffic_weight_green_frontend >= 0 && var.traffic_weight_green_frontend <= 100
    error_message = "Traffic weight must be between 0 and 100."
  }
}

variable "traffic_weight_green_backend" {
  description = "Traffic weight for green deployment (0-100)"
  type        = number
  default     = 0
  
  validation {
    condition     = var.traffic_weight_green_backend >= 0 && var.traffic_weight_green_backend <= 100
    error_message = "Traffic weight must be between 0 and 100."
  }
}

# ASG 크기 제어
variable "blue_instance_count_frontend" {
  description = "Number of instances for blue deployment"
  type = object({
    # desired = number
    min     = number
    max     = number
  })
  default = {
    # desired = 1
    min     = 1
    max     = 2
  }
}

variable "blue_instance_count_backend" {
  description = "Number of instances for blue deployment"
  type = object({
    # desired = number
    min     = number
    max     = number
  })
  default = {
    # desired = 1
    min     = 1
    max     = 2
  }
}

variable "green_instance_count_frontend" {
  description = "Number of instances for green deployment"
  type = object({
    # desired = number
    min     = number
    max     = number
  })
  default = {
    # desired = 0
    min     = 0
    max     = 0
  }
}

variable "green_instance_count_backend" {
  description = "Number of instances for green deployment"
  type = object({
    # desired = number
    min     = number
    max     = number
  })
  default = {
    # desired = 0
    min     = 0
    max     = 0
  }
}

variable "mysql_root_password" {
  description = "MySQL root 사용자 비밀번호"
  type        = string
  default = ""
  sensitive = true
}

variable "mysql_database_name" {
  description = "MySQL에 생성할 데이터베이스 이름"
  type        = string
  sensitive = true
  default = ""

}

variable "mysql_user_name" {
  description = "MySQL에 생성할 일반 사용자 이름"
  type        = string
  sensitive = true
  default = ""
}

variable "mysql_internal_ip" {
  description = "MySQL 인스턴스의 내부 IP 주소"
  type        = string
  default     = ""
}