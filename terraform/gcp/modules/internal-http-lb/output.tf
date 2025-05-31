output "backend_service_self_link" {
  value = google_compute_region_backend_service.this.self_link
}

output "url_map_self_link" {
  value = google_compute_region_url_map.this.self_link
}

output "http_proxy_self_link" {
  value = google_compute_region_target_http_proxy.this.self_link
}

