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


locals {
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
    }
  ]
}

module "firewall" {
  source         = "../../modules/firewall"
  vpc_name       = module.network.vpc_name
  firewall_rules = local.firewall_rules
}

###project 관련
