output "subnets" {
  value = {
    for name, subnet in google_compute_subnetwork.subnets :
    name => {
      name      = subnet.name
      cidr      = subnet.ip_cidr_range
      component = subnet.labels["component"]
      region    = subnet.region
      self_link = subnet.self_link
    }
  }
}