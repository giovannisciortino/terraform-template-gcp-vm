terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

variable "gcp_service_account_json" {
  type = string
}

variable "gcp_project" {
  type = string
}

variable "gcp_region" {
  type = string
  default = "us-central1"
}

variable "gcp_zone" {
  type = string
  default = "us-central1-c"
}

variable "gcp_vpc_network" {
  type = string
  default = "terraform-network"
}

variable "gcp_compute_instance_machine_type" {
  type = string
  default = "f1-micro"
}

variable "gcp_compute_instance_name" {
  type = string
  default = "terraform-instance"
}

variable "gcp_compute_instance_image" {
  type = string
  default = "debian-cloud/debian-11"
}

provider "google" {
  credentials = jsondecode(var.gcp_service_account_json)

  project = var.gcp_project
  region  = var.gcp_region
  zone    = var.gcp_zone
}

resource "google_compute_network" "vpc_network" {
  name = var.gcp_vpc_network
}

resource "google_compute_instance" "vm_instance" {
  name         = var.gcp_compute_instance_name
  machine_type = var.gcp_compute_instance_machine_type

  boot_disk {
    initialize_params {
      image = var.gcp_compute_instance_image
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}
