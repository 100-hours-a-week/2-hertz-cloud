############################################################
# Target Group(Backend Service) – GCP HTTP(S) LB 전용
############################################################
resource "google_compute_backend_service" "this" {
  name          = var.name
  protocol      = var.protocol          # HTTP | HTTPS | HTTP2 | GRPC
  port_name     = var.port_name         # "http" 기본
  timeout_sec   = var.timeout_sec
  health_checks = [var.health_check]    # self_link

dynamic "backend" {
  for_each = var.backends
  content {
    group            = backend.value.instance_group
    balancing_mode   = lookup(backend.value, "balancing_mode", "UTILIZATION")
    capacity_scaler  = lookup(backend.value, "capacity_scaler", 1.0)  # 0.0–1.0
  }
}

  connection_draining_timeout_sec = var.connection_draining_sec
  log_config {
    enable      = var.log_enable
    sample_rate = var.log_sample_rate
  }
}