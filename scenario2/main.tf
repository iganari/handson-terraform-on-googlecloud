# 0. 必要なAPIの有効化
locals {
  scenario2_services = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com" # 内部ネットワーク処理等で要求されることがあるため追加
  ])
}

resource "google_project_service" "scenario2_api" {
  for_each           = local.scenario2_services
  service            = each.value
  disable_on_destroy = false
}

# 1. DBパスワードのランダム生成
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# 2. Secret Managerにパスワードを保存
resource "google_secret_manager_secret" "db_pass_secret" {
  secret_id = "db-password"
  replication {
    auto {}
  }
  depends_on = [google_project_service.scenario2_api]
}

resource "google_secret_manager_secret_version" "db_pass_version" {
  secret      = google_secret_manager_secret.db_pass_secret.id
  secret_data = random_password.db_password.result
}

# 3. Cloud SQL (PostgreSQL) インスタンス
resource "google_sql_database_instance" "postgres" {
  name             = "handson-postgres-instance"
  database_version = "POSTGRES_14"
  region           = "asia-northeast1"
  deletion_protection = false 

  settings {
    tier = "db-f1-micro"
  }
  depends_on = [google_project_service.scenario2_api]
}

resource "google_sql_user" "db_user" {
  name     = "handson_user"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
}

# 4. Cloud Run のサービスアカウント
resource "google_service_account" "run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
  depends_on   = [google_project_service.scenario2_api]
}

# 5. Cloud Run に Secret の参照権限を付与
resource "google_secret_manager_secret_iam_member" "run_sa_secret_access" {
  secret_id = google_secret_manager_secret.db_pass_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

# 6. Cloud Run (v2) のデプロイ
resource "google_cloud_run_v2_service" "app" {
  name     = "handson-app"
  location = "asia-northeast1"

  template {
    service_account = google_service_account.run_sa.email

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_pass_secret.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.scenario2_api,
    google_secret_manager_secret_iam_member.run_sa_secret_access
  ]
}
