
# シナリオ1：【IaaS】VPCとCompute Engineで作るセキュアなWebサーバー環境

## 概要

Google Cloud上にカスタムVPCネットワークを構築し、外部IPアドレスを持たないプライベートなCompute Engine（VM）インスタンスを作成します。パブリックインターネットからの直接攻撃を防ぎつつ、Cloud NATを経由して安全にパッチ適用やパッケージインストール（Nginx）を行うセキュアなIaaS基盤の構築手法を学びます。

## 構成図

```mermaid
flowchart TD
    Internet((インターネット))
    IAP["Identity-Aware Proxy<br/>(IAP)"]

    subgraph VPC ["カスタム VPC (handson-vpc)"]
        Router["Cloud Router"]
        NAT["Cloud NAT"]
        
        subgraph Subnet ["プライベートサブネット (10.0.1.0/24)"]
            VM["Compute Engine (VM)<br/>・外部IPなし<br/>・Nginx自動導入"]
        end
    end

    VM -->|"アウトバウンド通信"| NAT
    NAT --> Router
    Router -->|"パッチ取得・更新"| Internet
    IAP -->|"SSH接続 (Port 22)"| VM
```


## 作成されるリソース

* **VPC / Subnet**: 独自定義したプライベートネットワーク空間
* **Cloud Router / Cloud NAT**: パブリックIPを持たないVMが外部（インターネット）へ通信するためのNAT環境
* **Firewall Rule**: IAP（35.235.240.0/20）からのSSH接続（Port 22）のみを許可するセキュリティルール
* **Compute Engine (VM)**: `e2-micro` インスタンス。起動時スクリプト（`metadata_startup_script`）でNginxを自動セットアップ

## このハンズオンで学べること

* Terraformを使った基本ネットワーク（VPC / Subnet）の構築手法
* 外部IPを持たないプライベートVMの安全な運用設計
* `metadata_startup_script` を用いたプロビジョニングの自動化
* `depends_on` によるリソース作成順序の依存関係制御

---

# シナリオ2：【PaaS】Cloud Run × Cloud SQLのモダンプラットフォーム構成

## 概要

サーバー管理が不要なコンテナ実行環境 **Cloud Run** と、フルマネージドデータベース **Cloud SQL (PostgreSQL)** を連携させるモダンなアプリケーション基盤を構築します。データベースの接続パスワードは Terraform の `random` プロバイダーで自動生成し、**Secret Manager** で安全に暗号化保存して Cloud Run へ注入する構成を実践します。

## 構成图

```mermaid
flowchart TD
    User((ユーザー))
    
    subgraph GCP ["Google Cloud"]
        Run["Cloud Run (v2)<br/>(handson-app)"]
        SM["Secret Manager<br/>(db-password)"]
        DB[("Cloud SQL (PostgreSQL)<br/>(handson-postgres)")]
        SA["Cloud Run サービスアカウント"]
    end

    User -->|"HTTPアクセス"| Run
    Run -->|"環境変数経由で参照"| SM
    Run -->|"DBアクセス"| DB
    SA -.->|"権限付与"| Run
    SA -.->|"Secret参照権限"| SM
```

## 作成されるリソース

* **Cloud Run (v2)**: アプリケーションコンテナの実行環境（サンプルコンテナイメージを使用）
* **Cloud SQL**: PostgreSQL 14 インスタンス (`db-f1-micro`) およびデータベースユーザー
* **Secret Manager**: DBパスワードを安全に管理・保管するシークレットストア
* **Service Account & IAM**: Cloud RunがSecret Managerから安全に暗号キーを取得するための最小権限設定
* **Random Password**: 予測不可能な16桁のランダムパスワード自動生成

## このハンズオンで学べること

* PaaS（Cloud Run）とマネージドDB（Cloud SQL）のインフラコード化
* 機密情報（DBパスワード等）をハードコードせず、Secret Managerを挟んで安全にデプロイする設計
* サービスアカウントを用いた最小権限（IAM）の付与パターン

---

# シナリオ3：【SaaS / マネージド】Cloud Storage × BigQueryで作る分析基盤

## 概要

大容量データを保存するデータレイク **Cloud Storage (GCS)** と、超高速なデータウェアハウス **BigQuery** を組み合わせた、完全サーバーレスなデータ分析プラットフォームを構築します。データパイプライン処理を行うプログラム（サービスアカウント）を発行し、各サービスに対する適切な操作権限（IAM）を設定します。

## 構成図

```mermaid
flowchart TD
    Pipeline["データパイプライン / 処理プログラム"]
    
    subgraph GCP ["Google Cloud"]
        SA["データパイプライン用 SA<br/>(data-pipeline-sa)"]
        
        subgraph Storage ["データレイク層"]
            GCS[("Cloud Storage (GCS)<br/>(ログ・CSVファイル等)")]
        end
        
        subgraph Analytics ["データウェアハウス層"]
            BQ_DS["BigQuery Dataset"]
            BQ_Table[("BigQuery Table<br/>(access_logs)")]
            BQ_DS --- BQ_Table
        end
    end

    Pipeline -->|"SA権限で認証"| SA
    SA -->|"1. ファイルアップロード"| GCS
    SA -->|"2. データロード・クエリ実行"| BQ_Table
```

## 作成されるリソース

* **Cloud Storage (GCS Bucket)**: Rawデータ（ログやCSV等）を保持するデータレイク用バケット
* **BigQuery Dataset & Table**: 構造化データを格納する分析用データベースとテーブル（スキーマ自動定義付き）
* **Service Account**: データパイプライン（バッチ処理等）専用の実行アカウント
* **IAM Member**: サービスアカウントに対する「GCS書き込み権限（`storage.objectAdmin`）」および「BigQueryデータ編集権限（`bigquery.dataEditor`）」の付与

## このハンズオンで学べること

* GCSやBigQueryなど、サーバーレス・マネージドサービス群の環境構築
* JSON形式を用いた BigQuery テーブルスキーマ（カラム定義）のコード管理
* リソース削除保護設定（`deletion_protection` / `force_destroy`）の扱いとハンズオン時の注意事項
