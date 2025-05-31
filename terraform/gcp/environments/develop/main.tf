############################################################
# Terraform Backend 및 Provider 선언
############################################################
terraform {
  backend "remote" {
    organization = "hertz-tuning"
    workspaces {
      name = "gcp-develop"
    }
  }
}

# 기존에 생성된 리소스(공유 VPC 등) 상태 조회
data "terraform_remote_state" "shared" {
  backend = "remote"
  config = {
    organization = "hertz-tuning"
    workspaces = {
      name = "gcp-shared"
    }
  }
}

provider "google" {
  credentials = var.dev_gcp_sa_key
  project     = var.dev_gcp_project_id
  region      = var.region
}

############################################################
# 네트워크/라우팅 및 NAT 리소스
############################################################

# Cloud Router 생성
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = data.terraform_remote_state.shared.outputs.vpc_self_link
}

# Cloud NAT용 외부 고정 IP
resource "google_compute_address" "nat_ip" {
  name   = "${var.vpc_name}-nat-ip"
  region = var.region
}

# Cloud NAT 설정
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    for_each = local.nat_subnet_info
    content {
      name                    = subnetwork.value.self_link
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }
}

locals {
  nat_subnet_info = data.terraform_remote_state.shared.outputs.nat_subnet_info
  firewall_rules = data.terraform_remote_state.shared.outputs.firewall_rules
}

############################################################
# 헬스 체크 모듈 (Backend/Frontend 분리)
############################################################

module "hc_backend" {
  source        = "../../modules/health-check"
  name          = "backend-http-hc"
  port          = 8080
  request_path  = "/health"
}

module "hc_frontend" {
  source        = "../../modules/health-check"
  name          = "frontend-http-hc"
  port          = 80
  request_path  = "/health"
}

locals {
  region           = var.region
  subnet_self_link = data.terraform_remote_state.shared.outputs.nat_b_subnet_self_link
  vpc_self_link = data.terraform_remote_state.shared.outputs.vpc_self_link
}

############################################################
# 백엔드(Backend) ASG - Blue/Green
############################################################

# Blue
# 1) Internal 전용 MIGs (Internal LB용)
module "backend_internal_asg_blue" {
  source           = "../../modules/mig-asg"
  name             = "backend-internal-blue"
  region           = var.region
  subnet_self_link = local.subnet_self_link
  disk_size_gb     = 20
  machine_type     = "e2-medium"
  desired          = 1
  min              = 1
  max              = 2
  cpu_target       = 0.8

  startup_tpl      = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key  = var.ssh_private_key
    docker_image           = var.docker_image_backend_blue
    use_ecr                = var.use_ecr
    aws_region             = var.aws_region
    aws_access_key_id      = var.aws_access_key_id
    aws_secret_access_key  = var.aws_secret_access_key
  })
  health_check = module.hc_backend.self_link
  tags = ["backend", "backend-hc","allow-vpn-ssh"]  # 헬스체크 태그 추가
  port_http = 8080
}

module "backend_internal_asg_green" {
  source           = "../../modules/mig-asg"
  name             = "backend-internal-green"
  region           = var.region
  subnet_self_link = local.subnet_self_link
  disk_size_gb     = 20
  machine_type     = "e2-medium"
  desired          = 0
  min              = 0
  max              = 2
  cpu_target       = 0.8

  startup_tpl      = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key  = var.ssh_private_key
    docker_image           = var.docker_image_backend_green
    use_ecr                = var.use_ecr
    aws_region             = var.aws_region
    aws_access_key_id      = var.aws_access_key_id
    aws_secret_access_key  = var.aws_secret_access_key
  })
  health_check = module.hc_backend.self_link
  tags = ["backend", "backend-hc","allow-vpn-ssh"]
  port_http = 8080
}


############################################################
# 백엔드 Internal Load Balancer (8080)
############################################################

resource "google_compute_subnetwork" "ilb_proxy_subnet" {
  name          = "${var.vpc_name}-ilb-proxy-subnet"
  ip_cidr_range = var.proxy_subnet_cidr 
  region        = var.region                 # 예: asia-east1
  network       = local.vpc_self_link          # VPC self_link

  # ────────────────────────────────────────────────────
  # 서브넷 용도를 "Internal HTTPS Load Balancer" 용도로 지정
  # 이 옵션이 있어야 프록시 전용 모드(subnet role)가 활성화됨
  purpose                         = "INTERNAL_HTTPS_LOAD_BALANCER"
  role    = "ACTIVE"
}

module "firewall_rules" {
  source = "../../modules/firewall-rules"

  rules = [
    {
      name          = "ilb-proxy-allow-internal"
      env           = var.env
      direction     = "INGRESS"
      priority      = 1000
      protocol      = "tcp"
      ports         = ["8080"]
      source_ranges = [""]
    }
  ]
}

module "backend_internal_lb" {
  source                = "../../modules/internal-http-lb"
  region                = var.region
  subnet_self_link      = local.subnet_self_link
  vpc_self_link         = data.terraform_remote_state.shared.outputs.vpc_self_link
  proxy_subnet_self_link = google_compute_subnetwork.ilb_proxy_subnet.self_link

  backend_name_prefix   = "backend-internal-lb"
  backends = [
    {
      instance_group  = module.backend_internal_asg_blue.instance_group
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    },
    {
      instance_group  = module.backend_internal_asg_green.instance_group
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  ]
  backend_hc_port     = 8080
  backend_timeout_sec = 30
  health_check_path   = "/health"
  port                = "8080"
  ip_prefix_length    = 28
}

############################################################
# 프론트엔드(Frontend) ASG - Blue/Green
############################################################

# Blue
module "frontend_asg_blue" {
  source           = "../../modules/mig-asg"
  name             = "frontend-blue"
  region           = var.region
  subnet_self_link = local.subnet_self_link
  disk_size_gb     = 20
  machine_type     = "e2-medium"
  desired          = 1
  min              = 1
  max              = 2
  cpu_target       = 0.8

  startup_tpl = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key = var.ssh_private_key
    docker_image          = var.docker_image_front_blue
    use_ecr               = false
    aws_region            = var.aws_region
    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
  })
  port_http = 80
  health_check = module.hc_frontend.self_link
  
}

# Green
module "frontend_asg_green" {
  source           = "../../modules/mig-asg"
  name             = "frontend-green"
  region           = var.region
  subnet_self_link = local.subnet_self_link
  disk_size_gb     = 20
  machine_type     = "e2-medium"
  desired          = 0
  min              = 0
  max              = 2
  cpu_target       = 0.8

  startup_tpl = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key = var.ssh_private_key
    docker_image          = var.docker_image_front_green
    use_ecr               = false
    aws_region            = var.aws_region
    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
  })
  port_http = 80
  health_check = module.hc_frontend.self_link
  tags=["allow-ssh-http","allow-vpn-ssh"]
}

############################################################
# External Backend/Frontend Target Group 생성 (HTTP LB 용)
############################################################

module "backend_tg" {
  source       = "../../modules/target-group"
  name         = "backend-backend-group"
  health_check = module.hc_backend.self_link
  backends = [
    {
      instance_group  = module.backend_internal_asg_blue.instance_group
      weight          = 100
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    },
    {
      instance_group  = module.backend_internal_asg_green.instance_group
      weight          = 0
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  ]
}

module "frontend_tg" {
  source       = "../../modules/target-group"
  name         = "frontend-backend-group"
  health_check = module.hc_frontend.self_link
  backends = [
    {
      instance_group  = module.frontend_asg_blue.instance_group
      weight          = 100
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    },
    {
      instance_group  = module.frontend_asg_green.instance_group
      weight          = 0
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  ]
}

############################################################
# 외부 HTTPS LB + URL Map (프론트엔드 기본, /api/* 백엔드)
############################################################

module "frontend_lb" {
  source           = "../../modules/external-https-lb"
  name             = "frontend-lb"
  domains          = [var.domain_frontend]
  backend_service  = module.backend_tg.backend_service_self_link      # /api/* 경로용
  frontend_service = module.frontend_tg.backend_service_self_link     # 그 외 기본 경로용
}



resource "google_compute_firewall" "allow_internal_hc" {
  name    = "${var.vpc_name}-allow-internal-hc"
  network = data.terraform_remote_state.shared.outputs.vpc_self_link

  direction = "INGRESS"
  priority  = 1000

  # GCP 헬스체크 IP 범위 (HTTP/HTTPS 헬스체크용)
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]

  allow {
    protocol = "tcp"
    ports    = ["8080"]      # 헬스체크 포트(Backend VM의 헬스 엔드포인트)
  }

  # 헬스체크 트래픽을 수신할 Backend VM에 붙은 태그
  target_tags = ["backend-hc"]
  description = "Allow GCP Internal LB health checks (TCP:8080) to backend VMs"
}

resource "google_compute_firewall" "allow_ilb_proxy_to_backend" {
  name    = "${var.vpc_name}-allow-ilb-proxy-to-backend"
  network = data.terraform_remote_state.shared.outputs.vpc_self_link

  direction = "INGRESS"
  priority  = 1000

  # ILB Proxy-Only Subnet CIDR
  # 예: var.proxy_subnet_cidr = "10.10.31.0/28"
  source_ranges = [ var.proxy_subnet_cidr ]

  allow {
    protocol = "tcp"
    ports    = ["8080"]      # 내부 LB(Proxy)에서 백엔드 VM으로 보내는 HTTP 포트
  }

  target_tags = ["backend"]  # 백엔드 VM에 붙어 있어야 함
  description = "Allow Internal LB proxy (subnet ${var.proxy_subnet_cidr}) to reach backend VMs on TCP/8080"
}