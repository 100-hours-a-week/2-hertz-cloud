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

  # ───────────────────────────────────────────────────────────────────
  # 1) host_rule: 어떤 도메인/호스트 이름에 대해 이 URL Map을 적용할 것인지
  #    만약 “모든 호스트(와일드카드)”로 적용하고 싶다면 “*” 사용
  #    또는 특정 도메인만 묶고 싶다면 ["app.example.com"] 등으로 지정
  # ───────────────────────────────────────────────────────────────────
  host_rule {
    hosts        = ["*"]                     # 모든 호스트(와일드카드)
    path_matcher = "main-matcher"            # 아래 path_matcher 이름과 동일해야 함
  }

  # ───────────────────────────────────────────────────────────────────
  # 2) path_matcher: 경로(/api/* 등)에 따라 어떤 BackendService로 보낼지
  # ───────────────────────────────────────────────────────────────────
  path_matcher {
    name            = "main-matcher"
    default_service = var.frontend_service      # 기본(예: "/") 요청을 받을 서비스

    path_rule {
      paths   = ["/api/*"]                     # /api/로 시작하는 모든 URL
      service = var.backend_service            # /api/* 요청은 backend_service로 보냄
    }
  }

  # ───────────────────────────────────────────────────────────────────
  # 3) default_service: 만약 호스트/경로 매칭이 전혀 안 되는 요청이 들어올 경우
  #    최종적으로 어떤 서비스로 보낼지 지정
  #    (보통 “front엔드” 혹은 404 페이지 용으로 간단히 잡아둠)
  # ───────────────────────────────────────────────────────────────────
  default_service = var.frontend_service
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




