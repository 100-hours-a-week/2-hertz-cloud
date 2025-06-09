
# 현재 배포 상태 출력
output "active_deployment" {
  description = "Currently active deployment color"
  value       = var.active_deployment
}
output "blue_deployment_status" {
  description = "Blue deployment status"
  value = {
    # backend_instances  = var.blue_instance_count.desired
    # frontend_instances = var.blue_instance_count.desired
    # traffic_weight     = local.normalized_blue_weight
    docker_images = {
      backend  = var.docker_image_backend_blue
      frontend = var.docker_image_front_blue
    }
  }
  sensitive = true
}

output "green_deployment_status" {
  description = "Green deployment status"
  value = {
    # backend_instances  = var.green_instance_count.desired
    # frontend_instances = var.green_instance_count.desired
    # traffic_weight     = local.normalized_green_weight
    docker_images = {
      backend  = var.docker_image_backend_green
      frontend = var.docker_image_front_green
    }
  }
  sensitive = true
}

# 인스턴스 그룹 정보
output "instance_groups" {
  description = "Instance group information"
  value = {
    backend_blue   = module.backend_internal_asg_blue.instance_group
    backend_green  = module.backend_internal_asg_green.instance_group
    frontend_blue  = module.frontend_asg_blue.instance_group
    frontend_green = module.frontend_asg_green.instance_group
  }
}

# ASG 인스턴스 크기 정보
output "blue_instance_count_frontend" {
  value = var.blue_instance_count_frontend
}
output "blue_instance_count_backend" {
  value = var.blue_instance_count_backend
}

output "green_instance_count_frontend" {
  value = var.green_instance_count_frontend
}

output "green_instance_count_backend" {
  value = var.green_instance_count_backend
}

output "traffic_weight_blue_frontend" {
  value = var.traffic_weight_blue_frontend
}

output "traffic_weight_blue_backend" {
  value = var.traffic_weight_blue_backend
}

output "traffic_weight_green_frontend" {
  value = var.traffic_weight_green_frontend
}

output "traffic_weight_green_backend" {
  value = var.traffic_weight_green_backend
}