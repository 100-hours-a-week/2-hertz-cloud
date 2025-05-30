output "vpc_name" {
  value = google_compute_network.shared_vpc.name
}

output "vpc_self_link" {
  value = google_compute_network.shared_vpc.self_link
}

output "subnets" {
  value = [for s in google_compute_subnetwork.shared_subnets : s.self_link]
}

output "firewall_rules" {
  value = local.firewall_rules
}

# shared/output.tf
output "nat_b_subnet_self_link" {
  value = google_compute_subnetwork.nat_b.self_link
}

output "nat_subnet_info" {
  value = {
    for k, s in google_compute_subnetwork.nat : k => {
      name      = s.name
      self_link = s.self_link
      cidr      = s.ip_cidr_range
    }
  }
}