output "backend_service_self_link" {
  value = google_compute_region_backend_service.this.self_link
}

output "url_map_self_link" {
  value = google_compute_url_map.this.self_link
}

output "http_proxy_self_link" {
  value = google_compute_target_http_proxy.this.self_link
}

output "internal_lb_ip" {
  description = "Internal HTTP LB 사설 IP"
  value       = google_compute_global_address.internal_ip.address
}