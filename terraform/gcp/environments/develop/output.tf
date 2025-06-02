
# 현재 배포 상태 출력
output "active_deployment" {
  description = "Currently active deployment color"
  value       = var.active_deployment
}
output "blue_deployment_status" {
  description = "Blue deployment status"
  value = {
    backend_instances  = var.blue_instance_count.desired
    frontend_instances = var.blue_instance_count.desired
    traffic_weight     = local.normalized_blue_weight
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
    backend_instances  = var.green_instance_count.desired
    frontend_instances = var.green_instance_count.desired
    traffic_weight     = local.normalized_green_weight
    docker_images = {
      backend  = var.docker_image_backend_green
      frontend = var.docker_image_front_green
    }
  }
  sensitive = true
}

output "frontend_lb_ip" {
  description = "프론트엔드 외부 HTTPS(443) LB IP"
  value       = module.frontend_lb.forwarding_rule_ip
}


# 로드밸런서 정보
output "load_balancer_info" {
  description = "Load balancer information"
  value = {
    # external-https-lb 모듈에서 내보내는 ‘forwarding_rule_ip’ 를 사용
    frontend_lb_ip = module.frontend_lb.forwarding_rule_ip

    # internal-http-lb 모듈에서 내보내는 ‘forwarding_rule_ip’ 를 사용
    backend_ilb_ip = module.backend_internal_lb.forwarding_rule_ip
  }
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