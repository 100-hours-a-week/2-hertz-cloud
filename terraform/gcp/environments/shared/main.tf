terraform {
  backend "remote" {
    organization = "hertz-tuning"

    workspaces {
      name = "terraform-gcp-shared"
    }
  }
}

provider "google" {
  credentials = jsondecode(var.dev_gcp_sa_key)
  project = var.project_id
  region  = var.region

}

module "network" {
  source     = "../../modules/network"
  project_id = var.project_id
  region     = var.region
  vpc_name   = var.vpc_name
  subnets    = var.subnets
}


###project 관련
