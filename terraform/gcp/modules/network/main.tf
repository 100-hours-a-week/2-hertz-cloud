resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  //ifecycle {
   // prevent_destroy = true
  //}
}

# Subnet 공통 생성 - public / private / nat 태그로 분리
resource "google_compute_subnetwork" "subnets" {
  for_each = {
    for subnet in concat(var.public_subnets, var.private_subnets, var.nat_subnets) :
    subnet.name => subnet
  }

  name          = each.value.name
  ip_cidr_range = each.value.cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = each.value.private_ip_google_access
 //ifecycle {
   // prevent_destroy = true
  //}

}

# Cloud Router
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc.name
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
    for_each = {
      for subnet in var.nat_subnets : subnet.name => subnet
    }
    content {
      name                    = google_compute_subnetwork.subnets[subnetwork.key].self_link
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }
}
