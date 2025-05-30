resource "google_compute_instance_template" "this" {
  name_prefix  = "${var.name}-tmpl-"
  machine_type = var.machine_type
  disk {
  
    auto_delete  = true
    boot         = true
    type         = "PERSISTENT"
  }
  network_interface {
    subnetwork = var.subnet_self_link
  }

  metadata_startup_script = var.startup_tpl
    

  service_account { scopes = ["https://www.googleapis.com/auth/cloud-platform"] }
}

resource "google_compute_region_instance_group_manager" "this" {
  name               = var.name
  region             = var.region
  base_instance_name = var.name
  target_size        = var.desired

  version {
    instance_template  = google_compute_instance_template.this.id
  }

  auto_healing_policies {
    health_check      = var.health_check
    initial_delay_sec = 60
  }
}

resource "google_compute_region_autoscaler" "this" {
  name   = "${var.name}-as"
  region = var.region
  target = google_compute_region_instance_group_manager.this.id

  autoscaling_policy {
    min_replicas    = var.min
    max_replicas    = var.max
    cpu_utilization { target = var.cpu_target }
  }
}
