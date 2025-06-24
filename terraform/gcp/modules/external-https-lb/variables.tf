variable "name" {
  description = "리소스 이름 프리픽스 (예: \"frontend-lb\")"
  type        = string
}

variable "domains" {
  description = "Managed SSL Certificate 도메인 리스트"
  type        = list(string)
}

variable "backend_service" {
  description = "External HTTP(S) Backend Service self_link"
  type        = string
}


variable "frontend_service" {
  description = "URL Map의 기본(프론트엔드) BackendService self_link"
  type        = string
}

variable "websocket_service" {
  description = "WebSocket 전용 BackendService self_link"
  type        = string
}

variable "lb_ip" {
  description = "External Load Balancer의 Global IP 주소 self_link"
  type        = object({
    address = string
    self_link = string
  })
}
variable "env" {
  description = "환경 이름 (예: \"dev\", \"prod\")"
  type        = string
  
}