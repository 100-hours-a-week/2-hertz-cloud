output "firewall_rule_names" {
  value = [for rule in google_compute_firewall.rules : rule.name]
}