output "frontend_lb_ip" {
  description = "프론트엔드 외부 HTTPS(443) LB IP"
  value       = module.frontend_lb.forwarding_rule_ip
}
