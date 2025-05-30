resource "google_compute_health_check" "this" {
  name = var.name
  http_health_check {
    port         = var.port
    request_path = var.request_path
  }
}