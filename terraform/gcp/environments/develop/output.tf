

output "backend_internal_lb_ip" {
  description = "백엔드 Internal HTTP LB(8080) 사설 IP"
  value       = module.backend_internal_lb.internal_lb_ip
}
output "frontend_lb_ip" {
  description = "프론트엔드 외부 HTTPS(443) LB IP"
  value       = module.frontend_lb.forwarding_rule_ip
}
