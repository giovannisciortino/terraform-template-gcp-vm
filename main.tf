terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.4"
    }
  }
}

variable "gcp_service_account_json_file" {
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
  default = "g1-small"
}

variable "gcp_compute_instance_name" {
  type = string
  default = "terraform-instance"
}

variable "gcp_compute_instance_image" {
  type = string
  default = "projects/fedora-cloud/global/images/fedora-cloud-base-gcp-38-1-6-x86-64"
}

variable "gcp_compute_instance_tag_service_name" {
  type = string
}

variable "gcp_compute_instance_count" {
  type = number
  default = 1
}

provider "google" {
  credentials = file(var.gcp_service_account_json_file)

  project = var.gcp_project
  region  = var.gcp_region
  zone    = var.gcp_zone
}

resource "google_compute_network" "vpc_network" {
  name = var.gcp_vpc_network
}

resource "google_service_account" "service_account" {
  account_id   = format("%s", split(".",var.gcp_compute_instance_tag_service_name)[0]  )
  display_name = "Custom SA for VM Instance"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output "private_key" {
  value = tls_private_key.ssh_key.private_key_pem
  sensitive=true
}

output "public_key" {
  value = tls_private_key.ssh_key.public_key_openssh
  sensitive=true
}

output "ssh_username" {
  value = "${split("@", google_service_account.service_account.email)[0]}"
  sensitive=false
}

output "vm_instance_ip_address" {
  value = google_compute_instance.vm_instance[*].network_interface[0].access_config[0].nat_ip
  sensitive=false
}

output "vm_instance_name" {
  value = google_compute_instance.vm_instance[*].name
  sensitive=false
}

resource "google_compute_instance" "vm_instance" {
  name         = "${format("%s-%03d", var.gcp_compute_instance_name, count.index + 1)}"
  machine_type = var.gcp_compute_instance_machine_type
  tags = [ replace(var.gcp_compute_instance_tag_service_name,".","-") ]
  count = var.gcp_compute_instance_count

  metadata = {
    ssh-keys = "${split("@", google_service_account.service_account.email)[0]}:${tls_private_key.ssh_key.public_key_openssh}"
  }


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

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.service_account.email
    scopes = ["cloud-platform"]
  }

}

resource "google_compute_firewall" "ssh-rule" {
  name = format("%s-ssh", replace(var.gcp_compute_instance_tag_service_name,".","-"))

  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  target_tags = [ replace(var.gcp_compute_instance_tag_service_name,".","-") ]
  source_ranges = ["0.0.0.0/0"]
}
