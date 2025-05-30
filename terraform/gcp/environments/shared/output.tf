output "vpc_name" {
  value = module.network.vpc_name
}

output "vpc_self_link" {
  value = module.network.vpc_self_link
}

output "subnets" {
  value = module.network.subnets
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