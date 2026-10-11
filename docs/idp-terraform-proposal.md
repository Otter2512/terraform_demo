# Đề xuất áp dụng Terraform cho iDP

> Tài liệu đi kèm slide "Terraform cho iDP – Technical Sharing" (phần 03, 04, 06).
> Chưa có tài khoản CMC nên mọi điểm liên quan tới CMC Cloud là **câu hỏi cho PoC**, chưa phải kết luận.

## 1. Phân lớp triển khai (slide 12)

```
Lớp 4 · Workloads        Helm qua Argo CD (đề xuất)
                         Kafka topics · Airflow · Trino · Spark jobs · AI services
Lớp 3 · Platform         Terraform + Helm provider
                         Ingress · cert-manager · monitoring · Strimzi · Spark Operator
Lớp 2 · Data & compute   Terraform + provider CMC
                         Kubernetes · PostgreSQL · Object Storage · VM
Lớp 1 · Foundation       Terraform + provider CMC
                         VPC · subnet · security group · DNS
```

- Terraform lo lớp 1 → 3: thay đổi ít, cần review chặt.
- Lớp 4 thay đổi thường xuyên (values chart, phiên bản ứng dụng) → đi qua GitOps (Argo CD), không phải chạy pipeline hạ tầng cho mỗi lần đổi cấu hình ứng dụng.
- Mẫu chung: **operator** cài ở lớp 3 bằng Terraform + Helm; **tài nguyên cụ thể** (Kafka cluster, topic, SparkApplication) là CR khai báo ở lớp 4.
- Ranh giới lớp 3/4 là quyết định cả team cần chốt trước sprint 1.

## 2. Phương án cho từng component (slide 13)

| Component | Cách triển khai | Lớp | Lưu ý |
|---|---|---|---|
| Kafka | Strimzi operator + CR Kafka | 3 + 4 | Cần StorageClass cho PVC |
| Spark | Spark Operator + SparkApplication | 3 + 4 | Job do Airflow kích hoạt, không tạo bằng Terraform |
| Airflow | Chart chính thức Apache Airflow | 4 | Metadata DB trên PostgreSQL |
| Trino | Chart Trino | 4 | Catalog trỏ Object Storage |
| Grafana | kube-prometheus-stack hoặc chart Grafana | 3 | Dashboard dạng code. Chart `grafana/grafana` đã deprecated, dùng repo `grafana-community` |
| PostgreSQL | Managed CMC hoặc CloudNativePG | 2 / 3 | Chốt phương án backup |
| Object Storage | Bucket S3-compatible của CMC | 2 | Data lake, có thể chứa state |
| AI Platform | Chưa xác định (KubeRay, KServe...) | 3 + 4 | Làm rõ phạm vi và GPU |

Ví dụ lớp 3 bằng Terraform + Helm: [examples/k8s-helm-grafana](../examples/k8s-helm-grafana/main.tf).

## 3. Cấu trúc repository đề xuất (slide 18)

```
idp-infra/
├── modules/                 # network, k8s-cluster, postgresql, platform-addons
├── stacks/                  # 1 stack = 1 state
│   ├── 00-bootstrap/        # bucket chứa state, tài khoản CI
│   ├── 10-network/          # lớp 1
│   ├── 20-k8s/              # lớp 2: cluster, node group
│   ├── 30-data/             # lớp 2: PostgreSQL, bucket
│   └── 40-platform/         # lớp 3: addons + operators qua helm_release
├── envs/
│   ├── dev/                 # <stack>.tfvars + backend.hcl
│   └── prod/
├── charts-values/           # values Helm: kafka, airflow, trino... (Terraform lớp 3 và Argo CD lớp 4 cùng đọc)
└── .github/workflows/       # plan trên PR, apply sau merge, drift hằng ngày
```

- **Stack theo lớp:** đổi network không khóa state của platform; lỗi ở một stack không lan sang stack khác.
- **Đánh số theo thứ tự phụ thuộc:** bootstrap → network → k8s → data → platform.
- **Tách 20-k8s và 40-platform:** provider Helm/Kubernetes cần thông tin cluster ngay lúc plan, cluster chưa tồn tại thì plan lỗi.
- **Môi trường qua tham số:**

  ```powershell
  cd stacks\20-k8s
  terraform init -backend-config=..\..\envs\dev\backend.hcl
  terraform plan -var-file=..\..\envs\dev\20-k8s.tfvars -out=tfplan
  ```

- **Liên kết giữa stack:** đọc output của nhau qua `terraform_remote_state` hoặc data source.
- **Remote state:** backend S3-compatible có `use_lockfile`, xem [examples/remote-state-s3](../examples/remote-state-s3/main.tf); dự phòng backend `pg` nếu Object Storage không hỗ trợ lock.

## 4. Tự động hóa và điểm cần phối hợp (slide 19)

| Tự động hóa bằng Terraform | Cần phối hợp CMC / Infra |
|---|---|
| Network, subnet, security group | Tài khoản, quota, hạn mức tài nguyên |
| Kubernetes cluster, node group | Credential cho CI và cách xoay vòng |
| PostgreSQL, Object Storage bucket | Kết nối mạng từ runner tới API CMC |
| Namespace, RBAC, quota trong K8s | DNS, chứng chỉ, kết nối VPN nội bộ |
| Operators và addons qua Helm | StorageClass, LoadBalancer, GPU node |
| Pipeline plan/apply, phát hiện drift | Backup/DR, quy trình duyệt thay đổi Prod |

Cột trái phụ thuộc provider CMC hỗ trợ đến đâu: resource nào provider không có thì làm tay hoặc gọi API riêng, và ghi lại thành ngoại lệ.

## 5. CMC Cloud: những điểm cần kiểm chứng (slide 11)

| Hạng mục | Cần xác nhận |
|---|---|
| Provider | Namespace trên Registry, version, ai maintain, tần suất cập nhật; có API tương thích OpenStack không |
| Xác thực | Loại credential, phạm vi quyền, cách xoay vòng key cho CI |
| Resource | Network, VM, Object Storage, Kubernetes, PostgreSQL có resource tương ứng không |
| Object Storage | Tương thích S3 tới mức nào, có hỗ trợ lock state không |
| Drift | Provider có đọc đủ thuộc tính để phát hiện sửa tay trên console |
| Giới hạn | Quota, rate limit API, thời gian tạo tài nguyên, endpoint private |

Thứ tự PoC đề xuất: network → VM → bucket (kèm thử remote state và lock) → Kubernetes → PostgreSQL.
Kiểm tra drift bằng cách sửa tay một tài nguyên trên console rồi chạy plan.

## 6. Technical gaps và rủi ro (slide 20–21)

| # | Vấn đề | Mức | Hành động |
|---|---|---|---|
| 1 | Chưa có tài khoản/sandbox CMC | Cao | Xin cấp sandbox Dev |
| 2 | Provider CMC: độ đầy đủ resource chưa rõ | Cao | PoC từng resource |
| 3 | Phát hiện drift phụ thuộc chất lượng provider | TB | Sửa tay trên console rồi chạy plan |
| 4 | Lock state trên Object Storage CMC | Cao | PoC; dự phòng backend pg |
| 5 | CI runner không tới được API private | TB | Self-hosted runner trong mạng CMC |
| 6 | Secret nằm trong state và plan file | Cao | Mã hóa, phân quyền, Vault |
| 7 | Tạo cluster và cài chart cùng root module | TB | Tách stack 20-k8s và 40-platform |
| 8 | Plan -/+ trên tài nguyên có dữ liệu | Cao | prevent_destroy, review bắt buộc |
| 9 | Không có rollback tự động | TB | Revert và apply; backup dữ liệu |
| 10 | Ranh giới Terraform và GitOps | TB | Chốt trước sprint 1 |
| 11 | Phạm vi AI Platform chưa rõ | TB | Làm rõ với kiến trúc |
| 12 | Ai được apply Prod | TB | CODEOWNERS, Environment reviewers |

Mức Cao là những điểm chặn việc triển khai hoặc gây mất an toàn. Gap 1 và 2 quyết định toàn bộ phần CMC.
Mục 10–12 là quyết định của team, nên đưa vào buổi họp kickoff.

## 7. Bước tiếp theo khi dự án bắt đầu (slide 22)

1. **PoC CMC:** provider + 1 VM + 1 bucket, thử remote state và lock.
2. **Skeleton repo:** dựng `idp-infra`, pipeline plan trên PR.
3. **End-to-end:** stack K8s + platform với một component (Grafana).
4. **Chốt quy trình:** ranh giới Terraform/GitOps, người duyệt Prod.
