# 0. 必要なAPIの有効化
locals {
  scenario1_services = toset([
    "compute.googleapis.com"
  ])
}

resource "google_project_service" "scenario1_api" {
  for_each           = local.scenario1_services
  service            = each.value
  # destroy時にAPIまで無効化すると他の影響が出やすいためfalseを推奨
  disable_on_destroy = false 
}

# 1. カスタムVPCの作成
resource "google_compute_network" "vpc_network" {
  name                    = "handson-vpc"
  auto_create_subnetworks = false

  # APIが有効になってから作成を開始する
  depends_on = [google_project_service.scenario1_api]
}

# 2. サブネットの作成
resource "google_compute_subnetwork" "subnet" {
  name          = "handson-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "asia-northeast1"
  network       = google_compute_network.vpc_network.id
}

# 3. Cloud Router (NAT用)
resource "google_compute_router" "router" {
  name    = "handson-router"
  region  = google_compute_subnetwork.subnet.region
  network = google_compute_network.vpc_network.id
}

# 4. Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = "handson-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 5. ファイアウォールルール
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

# 6. Compute Engine (VM)
resource "google_compute_instance" "web_server" {
  name         = "handson-web-server"
  machine_type = "e2-micro"
  zone         = "asia-northeast1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
  EOF
}
