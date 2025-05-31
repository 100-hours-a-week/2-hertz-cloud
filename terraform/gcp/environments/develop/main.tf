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
module "backend_asg_blue" {
  source           = "../../modules/mig-asg"
  name             = "tuning-backend-blue"
  region           = local.region
  subnet_self_link = local.subnet_self_link
  disk_size_gb     = 20
  machine_type     = "e2-medium"
  desired          = 1
  min              = 1
  max              = 2
  cpu_target       = 0.9

  startup_tpl = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key  = var.ssh_private_key
    docker_image           = var.docker_image_backend_blue
    use_ecr                = true
    aws_region             = var.aws_region
    aws_access_key_id      = var.aws_access_key_id
    aws_secret_access_key  = var.aws_secret_access_key
  })

  health_check = module.hc_backend.self_link
}

# Green
module "backend_asg_green" {
  source           = "../../modules/mig-asg"
  name             = "tuning-backend-green"
  region           = local.region
  subnet_self_link = local.subnet_self_link
  disk_size_gb     = 20
  machine_type     = "e2-medium"
  desired          = 0
  min              = 0
  max              = 1
  cpu_target       = 0.9

  startup_tpl = templatefile("${path.module}/scripts/vm-install.sh.tpl", {
    deploy_ssh_public_key  = var.ssh_private_key
    docker_image           = var.docker_image_backend_green
    use_ecr                = true
    aws_region             = var.aws_region
    aws_access_key_id      = var.aws_access_key_id
    aws_secret_access_key  = var.aws_secret_access_key
  })

  health_check = module.hc_backend.self_link
}

############################################################
# 백엔드 Internal Load Balancer (8080)
############################################################

module "backend_internal_lb" {
  source                = "../../modules/internal-http-lb"
  region                = var.region
  vpc_self_link = local.vpc_self_link
  subnet_self_link      = local.subnet_self_link
  backend_name_prefix   = "backend-internal-lb"

  backends = [
    {
      instance_group  = module.backend_asg_blue.instance_group
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    },
    {
      instance_group  = module.backend_asg_green.instance_group
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 0.0
    }
  ]

  backend_hc_port     = 8080
  backend_timeout_sec = 30
  health_check_path   = "/health"
  port               = "8080"
  ip_prefix_length   = 28
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

  health_check = module.hc_frontend.self_link
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
