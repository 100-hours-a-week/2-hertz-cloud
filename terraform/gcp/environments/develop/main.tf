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
   
}


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

module "hc" {
  source        = "../../modules/health-check"
  name          = "app-hc"
  port          = 8080
  request_path  = "/health"
}

module "asg" {
  source            = "../../modules/mig-asg"
  name              = "tuning-backend"
  region            = var.region
  subnet_self_link  = var.subnet_self_link
  startup_tpl       = templatefile(
  "${path.module}/scripts/vm-install.sh.tpl",
  { 
    
    deploy_ssh_public_key = var.ssh_private_key, # deploy 계정의 SSH 공개키
    
    image               = var.docker_image              # 필수
    use_ecr             = true                   # true/false
    aws_region          = var.aws_region                # optional
    aws_access_key_id   = var.aws_access_key_id         # optional
    aws_secret_access_key = var.aws_secret_access_key   # optional
  }
  )
  health_check      = module.hc.self_link
}
