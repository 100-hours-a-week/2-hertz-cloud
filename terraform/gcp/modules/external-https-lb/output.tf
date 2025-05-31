output "url_map_self_link" {
  value = google_compute_url_map.this.self_link
}

output "https_proxy_self_link" {
  value = google_compute_target_https_proxy.this.self_link
}

output "forwarding_rule_ip" {
  description = "외부 HTTPS LB 공인 IP"
  value       = google_compute_global_address.lb_ip.address
}