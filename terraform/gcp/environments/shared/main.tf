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

resource "google_compute_global_address" "dev_external_lb_ip" {
  name = "dev-external-lb-ip"
}
resource "google_compute_global_address" "prod_external_lb_ip" {
  name = "prod-external-lb-ip"
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
  subnetwork = google_compute_subnetwork.shared_subnets["${var.vpc_name}-public-b"].id

  dynamic "access_config" {
    for_each = [1]
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

}



resource "google_compute_network" "shared_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subnet 공통 생성 - public / private / nat 태그로 분리
resource "google_compute_subnetwork" "shared_subnets" {
  for_each = {
    for subnet in concat(local.public_subnets, local.private_subnets, local.nat_subnets) :
    subnet.name => subnet
  }

  name          = each.value.name
  ip_cidr_range = each.value.cidr
  region        = var.region
  network       = google_compute_network.shared_vpc.id
  private_ip_google_access = each.value.private_ip_google_access
}

resource "google_compute_subnetwork" "ilb_proxy_subnet" {
  name          = "${var.vpc_name}-ilb-proxy-subnet"
  ip_cidr_range = var.proxy_subnet_cidr 
  region        = var.region
  network       = google_compute_network.shared_vpc.id

  purpose = "INTERNAL_HTTPS_LOAD_BALANCER"
  role    = "ACTIVE"
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
    },
    {
      name          = "${var.vpc_name}-fw-lb-to-frontend"
      direction     = "INGRESS"
      priority      = 1000
      description   = "Allow External HTTPS LB proxy (130.211.0.0/22, 35.191.0.0/16) to reach Frontend on TCP:80"
      source_ranges = [
        "130.211.0.0/22",
        "35.191.0.0/16",
      ]
      target_tags   = ["frontend"]
      protocol      = "tcp"
      ports         = ["80"]
    },
    # # (4) GCP 헬스체크 → Frontend VM(포트 80) 허용
    # {
    #   name          = "${var.vpc_name}-fw-healthcheck-to-frontend"
    #   direction     = "INGRESS"
    #   priority      = 1000
    #   description   = "Allow GCP Health Checks (130.211.0.0/22, 35.191.0.0/16) to Frontend on TCP:80"
    #   source_ranges = [
    #     "130.211.0.0/22",
    #     "35.191.0.0/16",
    #   ]
    #   target_tags   = ["frontend"]
    #   protocol      = "tcp"
    #   ports         = ["80"]
    # },
    {
      name          = "${var.vpc_name}-fw-lb-to-backend"
      direction     = "INGRESS"
      priority      = 1000
      description   = "Allow External HTTPS LB proxy (130.211.0.0/22, 35.191.0.0/16) to reach Backend on TCP:8080"
      source_ranges = [
        "130.211.0.0/22",
        "35.191.0.0/16",
      ]
      target_tags   = ["backend"]
      protocol      = "tcp"
      ports         = ["8080"]
    },
    # {
    #   name          = "${var.vpc_name}-fw-healthcheck-to-backend"
    #   direction     = "INGRESS"
    #   priority      = 1000
    #   description   = "Allow GCP Health Checks (130.211.0.0/22, 35.191.0.0/16) to Backend on TCP:8080"
    #   source_ranges = [
    #     "130.211.0.0/22",
    #     "35.191.0.0/16",
    #   ]
    #   target_tags   = ["websocket"]
    #   protocol      = "tcp"
    #   ports         = ["9093"]
    # }
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

resource "google_compute_firewall" "shared_firewalls" {
  for_each = { for rule in local.firewall_rules : rule.name => rule }

  name    = "${var.vpc_name}-${each.key}"
  network = google_compute_network.shared_vpc.self_link

  direction     = each.value.direction
  priority      = each.value.priority
  description   = each.value.description
  source_ranges = each.value.source_ranges
  target_tags   = lookup(each.value, "target_tags", [])
  allow {
    protocol = each.value.protocol
    ports    = lookup(each.value, "ports", [])
  }

}

module "hc_backend" {
  source        = "../../modules/health-check"
  name          = "backend-http-hc"
  port          = 8080
  request_path  = "/api/ping"
}

module "hc_frontend" {
  source        = "../../modules/health-check"
  name          = "frontend-http-hc"
  port          = 80
  request_path  = "/"
}

# modules/health-check
module "hc_websocket" {
  source       = "../../modules/health-check"
  name         = "websocket-hc"
  port         = 9093
  request_path = "/ws/ping"
}

resource "google_compute_disk" "mysql_data" {
  name  = "${var.env}-mysql-data-disk-dev"
  type  = "pd-ssd"          # 성능을 위해 SSD(‘pd-ssd’)를 사용합니다. 필요에 따라 'pd-standard'로 변경 가능.
  zone  = "${var.region}-a" # MySQL 인스턴스가 위치한 zone과 동일해야 합니다.
  size  = 30               # GB 단위. 원하는 크기로 조정하세요.
}

resource "google_compute_disk" "mysql_data_prod" {
  name  = "${var.env}-mysql-data-disk-prod"
  type  = "pd-ssd"          # 성능을 위해 SSD(‘pd-ssd’)를 사용합니다. 필요에 따라 'pd-standard'로 변경 가능.
  zone  = "${var.region}-b" # MySQL 인스턴스가 위치한 zone과 동일해야 합니다.
  size  = 30               # GB 단위. 원하는 크기로 조정하세요.
}

resource "google_compute_resource_policy" "snapshot_policy" {
  name   = "${var.env}-mysql-snapshot-policy"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      hourly_schedule {
        hours_in_cycle = 8
        start_time     = "04:00"  # UTC 기준
      }
    }

    retention_policy {
      max_retention_days    = 30
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "attach_snapshot_policy" {
  name = google_compute_resource_policy.snapshot_policy.name
  disk = google_compute_disk.mysql_data_prod.name
  zone = google_compute_disk.mysql_data_prod.zone
}