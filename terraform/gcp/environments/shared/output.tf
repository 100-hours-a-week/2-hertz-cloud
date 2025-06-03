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
  value = google_compute_subnetwork.shared_subnets["${var.vpc_name}-nat-b"].self_link
}

output "nat_a_subnet_self_link" {
  value = google_compute_subnetwork.shared_subnets["${var.vpc_name}-nat-a"].self_link
}

output "nat_subnet_info" {
  value = {
    for s in google_compute_subnetwork.shared_subnets :
    s.name => {
      name      = s.name
      self_link = s.self_link
      cidr      = s.ip_cidr_range
    }
    if can(regex("-nat-", s.name))
  }
}


# Backend Health Check의 self_link
output "hc_backend_self_link" {
  description = "Self link of the backend HTTP health check"
  value       = module.hc_backend.self_link
}

# Frontend Health Check의 self_link
output "hc_frontend_self_link" {
  description = "Self link of the frontend HTTP health check"
  value       = module.hc_frontend.self_link
}