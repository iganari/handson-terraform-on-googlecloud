# 0. 必要なAPIの有効化
locals {
  scenario3_services = toset([
    "bigquery.googleapis.com",
    "iam.googleapis.com"
  ])
}

resource "google_project_service" "scenario3_api" {
  for_each           = local.scenario3_services
  service            = each.value
  disable_on_destroy = false
}

# 1. Cloud Storage バケット
resource "google_storage_bucket" "data_lake" {
  # プロジェクトIDなどを末尾に入れて一意な名前にしてください
  name          = "handson-data-lake-bucket-12345" 
  location      = "ASIA-NORTHEAST1"
  force_destroy = true 
  uniform_bucket_level_access = true
}

# 2. BigQuery データセット
resource "google_bigquery_dataset" "dataset" {
  dataset_id                  = "handson_dataset"
  friendly_name               = "Handson Dataset"
  description                 = "ハンズオン用のBigQueryデータセット"
  location                    = "asia-northeast1"
  delete_contents_on_destroy  = true 

  depends_on = [google_project_service.scenario3_api]
}

# 3. BigQuery テーブル (スキーマ定義付き)
resource "google_bigquery_table" "table" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "access_logs"
  deletion_protection = false

  schema = <<EOF
[
  {
    "name": "timestamp",
    "type": "TIMESTAMP",
    "mode": "REQUIRED"
  },
  {
    "name": "user_id",
    "type": "STRING",
    "mode": "NULLABLE"
  },
  {
    "name": "action",
    "type": "STRING",
    "mode": "NULLABLE"
  }
]
EOF
}

# 4. データ処理用のサービスアカウント
resource "google_service_account" "data_pipeline_sa" {
  account_id   = "data-pipeline-sa"
  display_name = "Data Pipeline Service Account"
  
  depends_on = [google_project_service.scenario3_api]
}

# 5. サービスアカウントへの権限付与 (GCSへの書き込み権限)
resource "google_project_iam_member" "gcs_admin" {
  project = "あなたのGCPプロジェクトID" # ご自身のプロジェクトIDに書き換えてください
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.data_pipeline_sa.email}"
}

# 6. サービスアカウントへの権限付与 (BigQueryへのデータ投入権限)
resource "google_project_iam_member" "bq_editor" {
  project = "あなたのGCPプロジェクトID" # ご自身のプロジェクトIDに書き換えてください
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.data_pipeline_sa.email}"
}
