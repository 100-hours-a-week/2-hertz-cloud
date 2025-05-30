terraform {
  backend "remote" {
    organization = "hertz-tuning"
    workspaces {
      name = "gcp-shared"
    }
  }
}
provider "google" {
  credentials = var.dev_gcp_sa_key
  project = var.dev_gcp_project_id
  region  = var.region

}


module "network" {
  source           = "../../modules/network"
  project_id       = var.dev_gcp_project_id
  region           = var.region
  vpc_name         = var.vpc_name
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  nat_subnets      = local.nat_subnets
}






module "firewall" {
  source         = "../../modules/firewall"
  vpc_name       = module.network.vpc_name
  firewall_rules = local.firewall_rules
}



locals {
  vpn_private_networks = concat(
    [for s in local.private_subnets : s.cidr],
    [for s in local.nat_subnets : s.cidr]
  )
}

resource "google_compute_address" "openvpn_static_ip" {
  name = "openvpn-static-ip"
  region = var.region

}


resource "google_compute_instance" "openvpn" {
  name                  = "openvpn"
  machine_type          = "e2-small"
  zone                  = "asia-east1-b"
  tags                  = ["openvpn", "openvpn-console", "allow-ssh-http"]  

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
    }
  }
  network_interface {
    subnetwork =  module.network.subnets["${var.vpc_name}-public-b"].self_link

    # enable_public_ip 가 true일 때만 access_config 블록을 생성
    dynamic "access_config" {
        for_each = [1] # 또는 enable_public_ip ? [1] : []
        content {
        nat_ip = google_compute_address.openvpn_static_ip.address
        }  
    }
  }

  metadata_startup_script = local.startup_script

  service_account {
    email  = var.default_sa_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

 //ifecycle {
   // prevent_destroy = true
  //}
}


module "backend" {
    source                = "../../modules/compute"
    name                  = "backend"
    machine_type          = "e2-medium"
    zone                  = "asia-east1-b"
    image                 = "ubuntu-os-cloud/ubuntu-2204-lts"
    disk_size_gb          = 10
    tags                  = ["allow-vpn-ssh"]
    
    subnetwork            = module.network.subnets["${var.vpc_name}-nat-b"].self_link
    
    # ✅ deploy 계정의 SSH 키는 base-init.sh.tpl에서 사용됨
    deploy_ssh_public_key = var.ssh_private_key
    
    service_account_email  = var.default_sa_email
    service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
   
}



locals {
  public_subnets = [
    {
      name                     = "${var.vpc_name}-public-a"
      cidr                     = "10.10.1.0/24"
      private_ip_google_access = true
      component                = "public"
    },
    {
      name                     = "${var.vpc_name}-public-b"
      cidr                     = "10.10.2.0/24"
      private_ip_google_access = true
      component                = "public"
    }
  ]

  private_subnets = [
    {
      name                     = "${var.vpc_name}-private-a"
      cidr                     = "10.10.11.0/24"
      private_ip_google_access = false
      component                = "private"
    },
    {
      name                     = "${var.vpc_name}-private-b"
      cidr                     = "10.10.12.0/24"
      private_ip_google_access = false
      component                = "private"
    }
  ]

  nat_subnets = [
    {
      name                     = "${var.vpc_name}-nat-a"
      cidr                     = "10.10.21.0/24"
      private_ip_google_access = true
      component                = "nat"
    },
    {
      name                     = "${var.vpc_name}-nat-b"
      cidr                     = "10.10.22.0/24"
      private_ip_google_access = true
      component                = "nat"
    }
  ]

    firewall_rules = [
    {
      name          = "ingress-public"
      env           = var.env
      direction     = "INGRESS"
      priority      = 1000
      protocol      = "tcp"
      ports         = ["22", "80", "443"]
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["allow-ssh-http"]
      description   = "Allow SSH/HTTP/HTTPS from anywhere"
    },
    {
      name          = "internal-all"
      env           = var.env
      direction     = "INGRESS"
      priority      = 1100
      protocol      = "all"
      ports         = []
      source_ranges = [
        for s in concat(local.public_subnets, local.private_subnets, local.nat_subnets) : s.cidr
      ]
      target_tags   = []
      description   = "Allow internal traffic"
    },
    {
      name          = "ingress-openvpn"
      env           = var.env
      direction     = "INGRESS"
      priority      = 1001
      protocol      = "udp"
      ports         = ["1194"]
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["openvpn"]
      description   = "Allow OpenVPN UDP traffic"
    },
    {
    name          = "openvpn-console"
    env           = var.env
    direction     = "INGRESS"
    priority      = 1002
    protocol      = "tcp"
    ports         = ["943", "443"]
    source_ranges = ["0.0.0.0/0"]
    target_tags   = ["openvpn"]
    description   = "Allow OpenVPN admin and client web access"
    },
    {
    name          = "ssh-from-vpn"
    env           = var.env
    direction     = "INGRESS"
    priority      = 1003
    protocol      = "tcp"
    ports         = ["22"]
    source_ranges = var.vpn_client_cidr_blocks 
    target_tags   = ["allow-vpn-ssh"]
    description   = "Allow SSH from VPN clients"
    }
  ]
}

locals {
  startup_script = join("\n", [
    templatefile("../../modules/compute/scripts/base-init.sh.tpl", {
      deploy_ssh_public_key = var.ssh_private_key
    }),
    templatefile("${path.module}/scripts/install-openvpn.sh.tpl", {
      openvpn_admin_password = var.openvpn_admin_password,
      vpn_private_networks   = join(",", local.vpn_private_networks)
    })
  ])
}






/*
module "bastion_openvpn" {
  source                = "../../modules/compute"
  name                  = "openvpn"
  machine_type          = "e2-small"
  zone                  = "asia-east1-b"
  image                 = "ubuntu-os-cloud/ubuntu-2204-lts"
  disk_size_gb          = 10
  tags                  = ["openvpn", "openvpn-console", "allow-ssh-http"]  

  #네트워크
  subnetwork            = module.network.subnets["${var.vpc_name}-public-b"].self_link
  enable_public_ip = true
  static_ip = google_compute_address.openvpn_static_ip.address
  #user_data
  extra_startup_script = templatefile("${path.module}/scripts/install-openvpn.sh.tpl", {
  openvpn_admin_password = var.openvpn_admin_password,
  vpn_private_networks   = join(",", local.vpn_private_networks)
})
  # ✅ deploy 계정의 SSH 키는 base-init.sh.tpl에서 사용됨
  deploy_ssh_public_key = var.ssh_private_key

  service_account_email  = var.default_sa_email
  service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}*/