terraform {
  required_version = "~> 1.15"
  required_providers {
    google = {
      source = "hashicorp/google"
      # version = "~>xx.yy.zz"   ## provider は固定化せずに最新バージョンを使っていくため
    }
    google-beta = {
      source = "hashicorp/google-beta"
      # version = "~> xx.yy.zz"   ## provider は固定化せずに最新バージョンを使っていくため
    }
  }
}

provider "google" {
  project = local.gc_project_id
  region  = local.default_region
}
provider "google-beta" {
  project = local.gc_project_id
  region  = local.default_region
}

locals {
  gc_project_id     = "your-gcp-project-id" # ★ここにご自身のプロジェクトIDを入力
  gc_project_number = data.google_project.project.number
  default_region    = "asia-northeast1"
  default_zone      = "asia-northeast1-a"
  common            = "hds-tf-gcp"
}

data "google_project" "project" {
  project_id = local.gc_project_id
}