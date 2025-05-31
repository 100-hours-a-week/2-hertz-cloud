terraform {
  backend "remote" {
    organization = "hertz-tuning"
    workspaces {
      name = "gcp-develop"
    }
  }
}

# develop/main.tf
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
  project = var.dev_gcp_project_id
  region  = var.region

}
/*
module "backend" {
    source                = "../../modules/compute"
    name                  = "backend"
    machine_type          = "e2-medium"
    zone                  = "asia-east1-b"
    image                 = "ubuntu-os-cloud/ubuntu-2204-lts"
    disk_size_gb          = 10
    tags                  = ["allow-vpn-ssh"]
    
    subnetwork            = data.terraform_remote_state.shared.outputs.nat_b_subnet_self_link
    
    # ✅ deploy 계정의 SSH 키는 base-init.sh.tpl에서 사용됨
    deploy_ssh_public_key = var.ssh_private_key
    
    service_account_email  = var.default_sa_email
    service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
   
}*/


# Cloud Router
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
   network = data.terraform_remote_state.shared.outputs.vpc_self_link
}

# 고정 외부 IP (Cloud NAT용)
resource "google_compute_address" "nat_ip" {
  name   = "${var.vpc_name}-nat-ip"
  region = var.region
}

# Cloud NAT
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
}

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
  region            = var.region
  subnet_self_link  = data.terraform_remote_state.shared.outputs.nat_b_subnet_self_link
        # 이미 만들어 둔 Health-Check 모듈
}

###############################################################################
# 1) BLUE (현재 프로덕션)
###############################################################################
module "backend_asg_blue" {
  source            = "../../modules/mig-asg"
  name              = "tuning-backend-blue"
  region            = local.region
  subnet_self_link  = local.subnet_self_link

  # 디스크 / 템플릿 · 오토스케일
  disk_size_gb      = 20
  machine_type      = "e2-medium"
  desired           = 1
  min               = 1
  max               = 2
  cpu_target        = 0.9

  # Startup Script (Blue 이미지 태그)
  startup_tpl = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key  = var.ssh_private_key
    docker_image           = var.docker_image_backend_blue   # 예: gcr.io/proj/app:blue
     use_ecr             = true                   # true/false
    aws_region          = var.aws_region                # optional
    aws_access_key_id   = var.aws_access_key_id         # optional
    aws_secret_access_key = var.aws_secret_access_key   # optional
  })

  health_check = module.hc_backend.self_link
}

###############################################################################
# 2) GREEN (차세대 버전—초기 target_size=0 → 헬스 통과 후 weight 조정)
###############################################################################
module "backend_asg_green" {
  source            = "../../modules/mig-asg"
  name              = "tuning-backend-green"
  region            = local.region
  subnet_self_link  = local.subnet_self_link

  disk_size_gb      = 20
  machine_type      = "e2-medium"
  desired           = 0            # 초기엔 0 or 1
  min               = 0
  max               = 1
  cpu_target        = 0.9

  startup_tpl = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key  = var.ssh_private_key
    docker_image           = var.docker_image_backend_green  # 예: gcr.io/proj/app:green
    use_ecr             = true                   # true/false
    aws_region          = var.aws_region                # optional
    aws_access_key_id   = var.aws_access_key_id         # optional
    aws_secret_access_key = var.aws_secret_access_key   # optional
  })

  health_check = module.hc_backend.self_link
}

# 3-4) Internal HTTP Load Balancer (백엔드 전용, 포트 8080) 모듈 호출
module "backend_internal_lb" {
  source = "../../modules/internal-http-lb"

  region                     = var.region
  subnet_self_link           = local.subnet_self_link
  backend_name_prefix        = "backend-internal-lb"

  backends = [
  {
    instance_group  = module.backend_asg_blue.instance_group
    # weight          = 100            ← TCP Backend Service에서는 weight 대신 capacity_scaler 사용
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  },
  {
    instance_group  = module.backend_asg_green.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 0.0   # 예: 그린 풀은 0% 트래픽
  }
]

  backend_hc_port     = 8080
  backend_timeout_sec = 30
  health_check_path   = "/health"
  port                = "8080"
  ip_prefix_length    = 28    # /28 등 필요에 따라 조정
}



module "frontend_asg_blue" {
  source            = "../../modules/mig-asg"
  name              = "frontend-blue"
  region            = var.region
  subnet_self_link  = local.subnet_self_link

  disk_size_gb      = 20
  machine_type      = "e2-medium"
  desired           = 1
  min               = 1
  max               = 2
  cpu_target        = 0.8

  startup_tpl = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key = var.ssh_private_key
    docker_image          = var.docker_image_front_blue  # 예: gcr.io/…/frontend:blue
    use_ecr               = false
    aws_region          = var.aws_region                # optional
    aws_access_key_id   = var.aws_access_key_id         # optional
    aws_secret_access_key = var.aws_secret_access_key   # optional
  })

  health_check = module.hc_frontend.self_link
}

# 2-3) Frontend MIG-ASG (Green)
module "frontend_asg_green" {
  source            = "../../modules/mig-asg"
  name              = "frontend-green"
  region            = var.region
  subnet_self_link  = local.subnet_self_link

  disk_size_gb      = 20
  machine_type      = "e2-medium"
  desired           = 0    # 그린은 초기엔 0
  min               = 0
  max               = 2
  cpu_target        = 0.8

  startup_tpl = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key = var.ssh_private_key
    docker_image          = var.docker_image_front_green  # 예: gcr.io/…/frontend:green
    use_ecr               = false
    aws_region          = var.aws_region                # optional
    aws_access_key_id   = var.aws_access_key_id         # optional
    aws_secret_access_key = var.aws_secret_access_key   # optional
  })

  health_check = module.hc_frontend.self_link
}

# ─────────────────────────────────────────────────────────────────────
# 먼저, Backend용 External BackendService 생성(경로 /api/*용)
module "backend_tg" {
  source       = "../../modules/target-group"
  name         = "backend-backend-group"
  health_check = module.hc_backend.self_link

  backends = [
    {
      instance_group  = module.backend_asg_blue.instance_group
      weight          = 100
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    },
    {
      instance_group  = module.backend_asg_green.instance_group
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

# 2-5) External HTTPS Load Balancer (URL-Map 모듈 사용)
module "frontend_lb" {
  source           = "../../modules/url-map"
  name             = "frontend-lb"
  domains          = [var.domain_frontend]

  # “/api/*” 경로는 backend_tg 로 분기
  backend_service  = module.backend_tg.backend_service_self_link

  # 기본 요청(“/” 또는 기타)은 frontend_tg 로
  frontend_service = module.frontend_tg.backend_service_self_link
}
