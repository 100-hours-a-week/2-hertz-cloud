variable "vpc_name" {
  description = "VPC 이름"
  type        = string
}

variable "firewall_rules" {
  description = "방화벽 규칙 리스트"
  type = list(object({
    name          = string
    env           = string
    direction     = string
    priority      = number
    protocol      = string
    ports         = list(string)
    source_ranges = list(string)
    target_tags   = list(string)
    description   = string
  }))
}