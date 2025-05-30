variable "vpc_name" { type = string }
variable "firewall_rules" {
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