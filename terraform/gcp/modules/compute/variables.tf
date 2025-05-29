variable "name" {
  description = "이 인스턴스의 이름"
  type        = string
}

variable "machine_type" {
  description = "머신 유형 (예: e2-micro)"
  type        = string
}

variable "zone" {
  description = "인스턴스가 배치될 존"
  type        = string
}

variable "tags" {
  description = "방화벽 대상이 될 인스턴스 태그"
  type        = list(string)
  default     = []
}

variable "image" {
  description = "부팅 디스크 이미지"
  type        = string
}

variable "disk_size_gb" {
  description = "디스크 크기 (GB)"
  type        = number
  default     = 10
}

variable "subnetwork" {
  description = "연결할 서브넷 self_link"
  type        = string
}

variable "startup_script" {
  description = "초기화 스크립트"
  type        = string
  default     = ""
}

variable "service_account_email" {
  description = "서비스 계정 이메일"
  type        = string
}

variable "deploy_ssh_public_key" {
  description = "deploy 계정에 등록할 SSH 공개 키"
  type        = string
  default     = ""
}

variable "extra_startup_script" {
  description = "추가 사용자 정의 startup script (예: OpenVPN 등)"
  type        = string
  default     = ""
}


variable "service_account_scopes" {
  description = "서비스 계정 권한 범위"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

# modules/vm/variables.tf
variable "enable_public_ip" {
  description = "이 VM에 외부 IP를 할당할지 여부"
  type        = bool
  default     = false
}

variable "static_ip" {
  type    = string
  default = ""
}
