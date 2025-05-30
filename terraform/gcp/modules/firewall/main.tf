resource "google_compute_firewall" "rules" {
  for_each = {
    for rule in var.firewall_rules : "${rule.env}-${rule.name}" => rule
  }

  name    = each.key
  network = var.vpc_name

  direction = each.value.direction
  priority  = each.value.priority

  allow {
    protocol = each.value.protocol
    ports    = each.value.ports
  }

  source_ranges = each.value.source_ranges
  target_tags   = each.value.target_tags
  description   = each.value.description
  //ifecycle {
   // prevent_destroy = true
  //}
}





