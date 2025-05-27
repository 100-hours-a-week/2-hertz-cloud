output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "vpc_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnets" {
  value = {
    for name, subnet in google_compute_subnetwork.subnets :
    name => {
      name      = subnet.name
      cidr      = subnet.ip_cidr_range
      region    = subnet.region
      self_link = subnet.self_link
    }
  }
}