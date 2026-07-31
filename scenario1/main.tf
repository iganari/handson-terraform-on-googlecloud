# 0. 必要なAPIの有効化
locals {
  scenario1_services = toset([
    "compute.googleapis.com"
  ])
}

resource "google_project_service" "scenario1" {
  for_each           = local.scenario1_services
  service            = each.value
  disable_on_destroy = false
}

# 1. カスタムVPCの作成
resource "google_compute_network" "vpc_network" {
  name                    = "handson-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.scenario1]
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

# 4. Cloud NAT用の静的外部IPアドレスを事前作成
resource "google_compute_address" "nat_ip" {
  name   = "handson-nat-ip"
  region = google_compute_subnetwork.subnet.region

  depends_on = [google_project_service.scenario1]
}

# 5. Cloud NAT (事前に作成した静的IPを固定割り当て)
resource "google_compute_router_nat" "nat" {
  name                               = "handson-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  
  # 手動割り当てに変更し、作成したIPを指定
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 6. ファイアウォールルール (IAPからのSSHアクセスのみ許可)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

# 7. Compute Engine (VM)
resource "google_compute_instance" "web_server" {
  name         = "handson-web-server"
  machine_type = "e2-micro"
  zone         = "asia-northeast1-a"

  boot_disk {
    initialize_params {
      # Ops Agentがサポートする最新のDebian 12を指定
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
    # 外部IPは付与しない
  }

  # 起動時にNginxをインストール
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
  EOF
}
