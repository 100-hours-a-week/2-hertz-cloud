resource "google_compute_instance" "vm" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone

  tags = var.tags

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork    = var.subnetwork
    access_config {}
  }

  metadata_startup_script = local.startup_script

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }
}

locals {
  startup_script = join("\n", [
    templatefile("${path.module}/scripts/base-init.sh.tpl", {
      deploy_ssh_public_key = var.deploy_ssh_public_key
    }),
    var.extra_startup_script
  ])
}