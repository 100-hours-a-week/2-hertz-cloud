resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
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

}