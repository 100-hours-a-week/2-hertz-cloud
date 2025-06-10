############################################################
# Internal HTTP Load Balancer Module (포트 8080)
############################################################

resource "google_compute_health_check" "this" {
  name = "${var.backend_name_prefix}-hc-${var.env}"
  http_health_check {
    port         = var.backend_hc_port     # 8080
    request_path = var.health_check_path   # "/health"
  }
}

resource "google_compute_region_backend_service" "this" {
  name                  = "${var.backend_name_prefix}-bs-${var.env}"
  protocol              = "HTTP"
  port_name             = "http"                            # << 추가
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
  depends_on = [ google_compute_health_check.this ]
  
}


resource "google_compute_region_url_map" "this" {
  name            = "${var.backend_name_prefix}-url-map-${var.env}"
  default_service = google_compute_region_backend_service.this.self_link
  region = var.region
}

resource "google_compute_region_target_http_proxy" "this" {
  name    = "${var.backend_name_prefix}-http-proxy-${var.env}"
  url_map = google_compute_region_url_map.this.self_link
  region = var.region
}

/*
resource "google_compute_address" "internal_ip" {
  name         = "${var.backend_name_prefix}-ip"
  address_type = "INTERNAL"
  subnetwork   = var.proxy_subnet_self_link
  region       = var.region
}*/

resource "google_compute_forwarding_rule" "this" {
  name                  = "${var.backend_name_prefix}-fr-${var.env}"
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = var.vpc_self_link
  // 수정: 로드 밸런서의 VIP가 할당될 일반 서브넷의 self_link를 사용
  subnetwork            = var.subnet_self_link # 백엔드 VM이 위치한 서브넷 또는 다른 일반 서브넷
  //ip_address          = google_compute_address.internal_ip.address // 주석 해제하여 특정 IP 지정 가능
  port_range            = var.port
  target                = google_compute_region_target_http_proxy.this.self_link
  region                = var.region
}