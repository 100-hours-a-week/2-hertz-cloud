##############################
# 필수 입력
##############################
variable "name" {
  description = "Backend Service 이름"
  type        = string
}

variable "health_check" {
  description = "Health Check self_link"
  type        = string
}

##############################
# backends 리스트
##############################
variable "backends" {
  description = "목표 백엔드 목록"
  type = list(object({
    instance_group   = string
    weight           = optional(number, 100)        # 기본 100
    balancing_mode   = optional(string, "UTILIZATION") # CONNECTION | RATE | UTILIZATION
    capacity_scaler  = optional(number, 1.0)        # 0.0–1.0, 기본 1.0
  }))
}

##############################
# 선택 입력
##############################
variable "protocol" {
  type    = string
  default = "HTTP"
}

variable "port_name" {
  type    = string
  default = "http"
}

variable "timeout_sec" {
  type    = number
  default = 30
}

variable "connection_draining_sec" {
  type    = number
  default = 0
}

variable "log_enable" {
  type    = bool
  default = false
}

variable "log_sample_rate" {
  type    = number
  default = 1.0
}