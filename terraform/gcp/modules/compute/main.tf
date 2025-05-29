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
    subnetwork = var.subnetwork

    # enable_public_ip 가 true일 때만 access_config 블록을 생성
    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {
        # static_ip(고정 IP)가 있으면 그걸 쓰고, 없으면 임시 IP
        nat_ip = var.static_ip != "" ? var.static_ip : null
      }
    }
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