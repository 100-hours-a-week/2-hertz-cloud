############################################################
# URL Map + HTTPS Proxy + Global Forwarding Rule Module
############################################################

resource "google_compute_managed_ssl_certificate" "this" {
  name = "${var.name}-cert"
  managed {
    domains = var.domains
  }
}

# URL Map 생성 (프론트엔드 및 백엔드 경로별 분기)

resource "google_compute_url_map" "this" {
  name            = "${var.name}-url-map"
  default_service = var.frontend_service

  path_matcher {
    name            = "main-matcher"
    default_service = var.frontend_service

    path_rule {
      paths   = ["/api/*"]
      service = var.backend_service
    }
  }
}


resource "google_compute_target_https_proxy" "this" {
  name             = "${var.name}-https-proxy"
  url_map          = google_compute_url_map.this.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.this.self_link]
}

resource "google_compute_global_address" "lb_ip" {
  name = "${var.name}-ip"
}

resource "google_compute_global_forwarding_rule" "https_fr" {
  name                  = "${var.name}-https-fr"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.this.self_link
  ip_address            = google_compute_global_address.lb_ip.address
}




