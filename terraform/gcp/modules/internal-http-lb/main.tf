############################################################
# Internal HTTP Load Balancer Module (포트 8080)
############################################################

resource "google_compute_health_check" "this" {
  name = "${var.backend_name_prefix}-hc"
  http_health_check {
    port         = var.backend_hc_port     # 8080
    request_path = var.health_check_path   # "/health"
  }
}

resource "google_compute_region_backend_service" "this" {
  name                  = "${var.backend_name_prefix}-bs"
  protocol              = "HTTP"
  health_checks         = [google_compute_health_check.this.self_link]
  timeout_sec           = var.backend_timeout_sec
  load_balancing_scheme = "INTERNAL_MANAGED"

  dynamic "backend" {
    for_each = var.backends
    content {
      group           = backend.value.instance_group
      balancing_mode  = lookup(backend.value, "balancing_mode", "UTILIZATION")
      capacity_scaler = lookup(backend.value, "capacity_scaler", 1.0)
    }
  }
}


resource "google_compute_url_map" "this" {
  name            = "${var.backend_name_prefix}-url-map"
  default_service = google_compute_region_backend_service.this.self_link
}

resource "google_compute_target_http_proxy" "this" {
  name    = "${var.backend_name_prefix}-http-proxy"
  url_map = google_compute_url_map.this.self_link
}

resource "google_compute_address" "internal_ip" {
  name         = "${var.backend_name_prefix}-ip"
  address_type = "INTERNAL"
  subnetwork   = var.subnet_self_link
  region       = var.region
}

resource "google_compute_forwarding_rule" "this" {
  name                  = "${var.backend_name_prefix}-fr"
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = var.vpc_self_link
  subnetwork            = var.subnet_self_link
  ip_address            = google_compute_address.internal_ip.address
  ports                 = [var.port]      # 리스트 형식
  target                = google_compute_target_http_proxy.this.self_link
  region                = var.region
}