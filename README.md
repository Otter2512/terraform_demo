# terraform-idp-demo

Source code đi kèm slide **"Terraform cho iDP – Technical Sharing"**. Demo toàn bộ vòng đời Terraform
(**init → plan → apply → thay đổi → drift → destroy**) chỉ với Docker Desktop, không cần tài khoản cloud.

- Terraform `1.16.5`, provider `kreuzwerker/docker ~> 3.0`
- Docker Desktop trên Windows: `host = "npipe:////./pipe/docker_engine"`

## Cấu trúc repo

```
terraform-idp-demo/
├── lab1-basic/               # 1 file main.tf đủ 5 khái niệm (slide 7), demo bước 1-5
├── modules/web_app/          # Module tái sử dụng: network + image nginx + container
│   ├── main.tf
│   ├── variables.tf          # app_name, external_port (có validation), image_tag, api_token (sensitive)
│   ├── outputs.tf            # url, container_id, container_name
│   └── versions.tf           # required_providers của module
├── envs/
│   ├── dev/                  # Root module DEV  -> state riêng, port 8081
│   │   ├── versions.tf       # pin version + backend local
│   │   ├── main.tf           # provider + gọi module
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── prod/                 # Giống dev, chỉ khác tfvars (port 8082)
├── examples/
│   ├── remote-state-s3/      # Backend S3-compatible + use_lockfile (slide 10), chỉ validate
│   └── k8s-helm-grafana/     # helm_release Grafana trên kind (slide 14), chỉ validate
├── docs/idp-terraform-proposal.md   # Đề xuất áp dụng cho iDP + gaps/rủi ro (slide 11-13, 18-22)
├── .github/workflows/terraform.yml  # PR -> plan + comment; merge -> apply (prod cần approve); drift hằng ngày
└── .gitignore
```

Mapping khái niệm → file (slide 4):

| Khái niệm | Ở đâu trong repo |
|---|---|
| Provider | `provider "docker"` trong `lab1-basic/main.tf`, `envs/*/main.tf`; pin version trong `versions.tf` |
| Resource | `docker_image`, `docker_container` (+ `docker_network` trong module) |
| Variable | `var.external_port`, `terraform.tfvars`, `TF_VAR_api_token` |
| Output | `url`, `container_id` |
| Module | `modules/web_app`, được gọi bởi `module "web_app"` ở mỗi env |
| State | `terraform.tfstate` trong từng thư mục (backend local) |

---

## Kịch bản demo (slide 17)

> Mọi lệnh chạy bằng PowerShell từ thư mục gốc repo. Output bên dưới là output thật (đã rút gọn), ID sẽ khác trên máy bạn.

| # | Thao tác | Điều cần thấy |
|---|---|---|
| 1 | init, plan, apply (`lab1-basic`) | Plan: 2 to add, mở localhost:8080 |
| 2 | Mở `terraform.tfstate` | ID container khớp với `docker ps` |
| 3 | Đổi port 8080 thành 8090, plan | must be replaced (-/+) |
| 4 | `docker rm -f demo-nginx`, plan | Drift: 1 to add, image giữ nguyên |
| 5 | `plan -out=tfplan`, `apply tfplan` | Apply đúng plan đã lưu |
| 6 | Apply `envs/dev` và `envs/prod` | Cùng module, 2 state, trang DEV và PROD |
| 7 | destroy | Dọn sạch tài nguyên |

### Bước 0 – Chuẩn bị trước giờ demo

```powershell
terraform version
docker version --format '{{.Server.Version}}'
docker ps -a --filter name=demo-nginx      # phải trống: không có container trùng tên/cổng 8080
```

```
Terraform v1.16.5
on windows_amd64
28.2.2
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

Nếu còn `demo-nginx` từ lần chạy trước: vào đúng thư mục đã tạo nó và chạy `terraform destroy`.

### Bước 1 – init, plan, apply

```powershell
cd lab1-basic
terraform init
terraform plan
terraform apply        # gõ "yes"
curl.exe -s http://localhost:8080 | Select-String "<title>"
```

```
Initializing provider plugins...
- Installing kreuzwerker/docker v3.9.0...
Terraform has been successfully initialized!

  # docker_container.web will be created
  # docker_image.nginx will be created
Plan: 2 to add, 0 to change, 0 to destroy.
Changes to Outputs:
  + url = "http://localhost:8080"

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
Outputs:
url = "http://localhost:8080"

<title>Welcome to nginx!</title>
```

Chạy lại `terraform plan` ngay sau đó → `No changes.` (tính **idempotent**).

### Bước 2 – mở state

```powershell
Select-String -Path terraform.tfstate -Pattern '"id": "[0-9a-f]{64}"' | Select-Object -First 1
docker ps --filter name=demo-nginx --format '{{.ID}} {{.Names}}'
```

```
"id": "570b49575a099bcd7b41476d7eece13740da10c77e3983f5bc6f62e845b03290",
570b49575a09 demo-nginx
```

Điểm cần nói: state là "sợi dây" nối resource trong code với container thật.

### Bước 3 – đổi port → replace (-/+)

```powershell
terraform plan -var external_port=8090
```

```
  # docker_container.web must be replaced
-/+ resource "docker_container" "web" {
      ~ ports {
          ~ external = 8080 -> 8090 # forces replacement
        }
    }
Plan: 1 to add, 0 to change, 1 to destroy.
```

Chỉ plan, **không apply**. Dùng `-var` để không phải sửa file, bước 5 vẫn chạy với cổng 8080.
Không dùng 8081 vì cổng này dành cho `envs/dev` ở bước 6.

### Bước 4 – drift: xóa container bên ngoài Terraform

```powershell
docker rm -f demo-nginx
terraform plan
```

```
docker_image.nginx: Refreshing state... [id=sha256:6784fb08...nginx:1.27]
docker_container.web: Refreshing state... [id=570b49575a09...]

  # docker_container.web will be created
Plan: 1 to add, 0 to change, 0 to destroy.
```

Điểm cần nói: refresh hỏi Docker thấy container không còn; image vẫn còn nên chỉ `1 to add`.
Trong CI dùng `terraform plan -detailed-exitcode` → exit code `2` = có drift.

### Bước 5 – plan -out rồi apply file plan

```powershell
terraform plan -out=tfplan
terraform apply tfplan          # KHÔNG hỏi "yes": plan đã được review rồi
```

```
Saved the plan to: tfplan
To perform exactly these actions, run the following command to apply:
    terraform apply "tfplan"

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

(Thêm) Plan cũ bị từ chối nếu state đã thay đổi sau khi plan:

```powershell
terraform plan -out=tfplan
terraform apply -auto-approve   # ai đó apply chen ngang
terraform apply tfplan
```

```
Error: Saved plan is stale
```

### Bước 6 – envs/dev và envs/prod: cùng module, 2 state

```powershell
cd ..\envs\dev
$env:TF_VAR_api_token = "dev-token-123"     # secret qua biến môi trường, không nằm trong code
terraform init
terraform plan
terraform apply -auto-approve
curl.exe -s http://localhost:8081
```

```
      + env = (sensitive value)
Plan: 3 to add, 0 to change, 0 to destroy.

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
url = "http://localhost:8081"

<h1>Hello from DEV</h1><p>app=demo-dev, nginx:1.27</p>
```

```powershell
cd ..\prod
$env:TF_VAR_api_token = "prod-token-456"
terraform init
terraform apply -auto-approve
curl.exe -s http://localhost:8082
docker ps --filter label=managed-by=terraform --format "table {{.Names}}\t{{.Ports}}"
```

```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
url = "http://localhost:8082"

<h1>Hello from PROD</h1><p>app=demo-prod, nginx:1.27</p>

NAMES           PORTS
demo-prod-web   0.0.0.0:8082->80/tcp
demo-dev-web    0.0.0.0:8081->80/tcp
```

**(Thêm) sensitive KHÔNG có nghĩa là được mã hóa** (slide 10):

```powershell
Select-String -Path terraform.tfstate -Pattern "prod-token-456" | Select-Object -First 1
```

```
terraform.tfstate:58:  "API_TOKEN=prod-token-456",
```

**(Thêm) validation chặn cấu hình sai:**

```powershell
terraform plan -var external_port=80
```

```
Error: Invalid value for variable
    │ var.external_port is 80
external_port phải là số nguyên trong khoảng 1024-65535.
```

> Mỗi terminal mới phải đặt lại `$env:TF_VAR_api_token`, nếu không Terraform sẽ dừng lại hỏi giá trị.

### Bước 7 – destroy

```powershell
cd ..\dev
$env:TF_VAR_api_token = "dev-token-123"
terraform destroy -auto-approve
curl.exe -s http://localhost:8082           # prod vẫn chạy: state tách biệt

cd ..\prod
$env:TF_VAR_api_token = "prod-token-456"
terraform destroy -auto-approve

cd ..\..\lab1-basic
terraform destroy -auto-approve
```

```
Destroy complete! Resources: 3 destroyed.
<h1>Hello from PROD</h1><p>app=demo-prod, nginx:1.27</p>
Destroy complete! Resources: 3 destroyed.
Destroy complete! Resources: 2 destroyed.
```

Lưu ý: `lab1-basic` không đặt `keep_locally` nên destroy sẽ xóa image `nginx:1.27`; module `web_app` thì có `keep_locally = true`.

Dọn file sinh ra trong lúc demo (tùy chọn, chạy ở thư mục gốc repo):

```powershell
Get-ChildItem -Recurse -File -Include tfplan,terraform.tfstate* | Remove-Item -Force
```

---

## CI/CD (slide 15, minh họa)

File [.github/workflows/terraform.yml](.github/workflows/terraform.yml):

```
Pull Request ──► fmt -check ──► validate ──► plan ──► comment kết quả plan lên PR ──► review, approve
Merge main ────► plan -out=tfplan (artifact 1 ngày) ──► apply dev ──► [chờ duyệt Environment prod] ──► apply tfplan prod ──► thông báo
Hằng ngày ─────► plan -detailed-exitcode ──► exit 2 = drift ──► mở issue cảnh báo
```

Cần cấu hình trên GitHub: Environments `dev`, `prod` (prod bật *Required reviewers*), secret `API_TOKEN`,
tùy chọn `NOTIFY_WEBHOOK_URL` để gửi thông báo.

## Remote state S3-compatible (slide 10)

[examples/remote-state-s3/main.tf](examples/remote-state-s3/main.tf): backend `s3` trỏ endpoint S3-compatible, các tham số
`skip_credentials_validation`, `skip_region_validation`, `skip_requesting_account_id`, `skip_s3_checksum`, `use_path_style`,
và `use_lockfile = true`. Chỉ kiểm tra cú pháp:

```powershell
cd examples\remote-state-s3
terraform init -backend=false
terraform validate
```

## Terraform + Helm (slide 14)

[examples/k8s-helm-grafana](examples/k8s-helm-grafana/main.tf): `helm_release` Grafana với `create_namespace`, version chart
được pin, values trong file riêng [values/grafana.yaml](examples/k8s-helm-grafana/values/grafana.yaml), mật khẩu admin lấy từ
`existingSecret` (không đi qua state), `atomic = true`. Đã `terraform validate`; **chưa chạy trên cluster**.

> Chart `grafana/grafana` ở `grafana.github.io` đã bị đánh dấu deprecated (01/2026); ví dụ dùng repo
> `https://grafana-community.github.io/helm-charts`, chart `grafana` version `13.5.0`.

Chạy thật trên kind (cần cài `kind`, `kubectl`):

```powershell
kind create cluster --name idp
kubectl create namespace monitoring
kubectl -n monitoring create secret generic grafana-admin `
  --from-literal=admin-user=admin --from-literal=admin-password=<mật-khẩu>
cd examples\k8s-helm-grafana
terraform init
terraform apply
kubectl -n monitoring port-forward svc/grafana 3000:80
```

---

## Những gì demo này KHÔNG thể hiện được so với triển khai thật trên cloud

| Chủ đề | Demo local | Thực tế trên cloud (CMC hoặc khác) |
|---|---|---|
| **Remote state** | State là file trên máy; mất máy là mất state | Backend S3-compatible (Object Storage) có versioning, mã hóa, phân quyền |
| **State locking** | Không có; 2 người apply cùng lúc → hỏng state | `use_lockfile` trên S3-compatible (cần storage hỗ trợ ghi có điều kiện) hoặc backend `pg` |
| **Provider CMC** | Chỉ dùng provider Docker | Provider của CMC (cần xác minh: namespace, độ hoàn thiện, resource hỗ trợ, rate limit) |
| **Xác thực** | Không cần credential | API key/token, service account, phân quyền least-privilege, xoay vòng key |
| **Secret management** | Biến môi trường + `sensitive` | Vault / Secret Manager / External Secrets; ephemeral/write-only khi provider hỗ trợ |
| **Mạng & bảo mật** | 1 Docker network | VPC, subnet, security group, NAT, LB, DNS, chứng chỉ |
| **Thời gian & chi phí** | Tạo/xóa trong vài giây, miễn phí | VM/K8s/DB mất vài phút đến hàng chục phút; tạo nhầm là mất tiền |
| **Replace có hậu quả** | Container mất, tạo lại ngay | Mất dữ liệu (disk, DB), đổi IP; cần `prevent_destroy`, `create_before_destroy`, backup |
| **Dependency giữa stack** | 1 stack/env | Nhiều stack (network → k8s → data → platform) liên kết qua `terraform_remote_state` hoặc data source |
| **CI chạy thật** | Workflow chỉ minh họa | Runner có quyền truy cập cloud (có thể self-hosted trong mạng CMC), remote state, policy check (tflint, checkov) |
| **Drift** | Chạy tay; chỉ thấy cái "hộp" (container), không thấy sửa bên trong (`docker exec`) | Job `plan -detailed-exitcode` hằng ngày + cảnh báo; chất lượng phụ thuộc provider |
| **Rollback** | Sửa code + apply lại | Không có "undo": revert commit + apply; dữ liệu đã mất phải restore backup |
| **Quota/giới hạn API** | Không có | Quota tài nguyên, rate limit API, resource tạo không đồng bộ (timeout) |
| **Import hạ tầng có sẵn** | Không có | `import` block cho tài nguyên đã tạo tay trên portal |
