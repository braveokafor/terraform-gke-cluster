terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = var.project 
  region  = var.region
  zone    = var.zone 
}


locals {
  vpc_network_name = "vpc-network-${var.environment}"
}

# NETWORKING
resource "google_project_service" "compute" {
  project = var.project
  service = "compute.googleapis.com"
}

resource "google_compute_network" "vpc_network" {
  name = local.vpc_network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
    name ="${local.vpc_network_name}-${var.subnet_region}"
    ip_cidr_range = var.subnet_cidr
    region = var.subnet_region
    network = google_compute_network.vpc_network.name
}

resource "google_compute_firewall" "https" {
  name    = "${local.vpc_network_name}-allow-https"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  target_tags = ["web"]
}

# GKE
resource "google_project_service" "gke_api" {
  project = var.project
  service = "container.googleapis.com"
}

resource "google_container_cluster" "gke-cluster" {
  name     = "cluster-${var.environment}"
  location = var.zone
  network  = google_compute_network.vpc_network.name 
  subnetwork = google_compute_subnetwork.subnet.name

  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "gke-nodes" {
  name       = "node-pool-${var.environment}"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
