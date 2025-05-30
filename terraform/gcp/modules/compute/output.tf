output "startup_script" {
  value = local.startup_script
}

output "instance_ip" {
  value = google_compute_instance.vm.network_interface[0].network_ip
}