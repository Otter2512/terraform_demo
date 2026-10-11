# =============================================================================
# VÍ DỤ MINH HỌA: Terraform gọi Helm qua helm_release (cài Grafana).
# Chạy trên cụm kind local; đây là ví dụ tham khảo, chưa demo trực tiếp.
# Cụm thật trên cloud dùng y hệt, chỉ khác phần kubeconfig.
#
# Lưu ý: không tạo cluster và cài chart trong cùng root module, vì provider
# helm cần thông tin cluster ngay lúc plan -> cluster thuộc stack 20-k8s,
# chart thuộc stack 40-platform.
# =============================================================================

terraform {
  required_version = "~> 1.16"

  required_providers {
    # Provider helm 3.x: khối kubernetes viết dạng attribute (kubernetes = {...}).
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

# Context trong kubeconfig. kind tạo context "kind-<tên cluster>".
variable "kube_context" {
  description = "Context kubeconfig (kind create cluster --name idp -> kind-idp)"
  type        = string
  default     = "kind-idp"
}

# Kết nối provider helm tới cluster.
provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = var.kube_context
  }
}

# Helm release Grafana.
# - version: PIN version chart, nâng có kế hoạch qua PR.
# - values: để trong file riêng -> review được trong PR như code.
# - Mật khẩu admin KHÔNG đi qua Terraform: chart đọc từ Secret có sẵn
#   (existingSecret trong values) -> không lọt vào state.
# - atomic: cài lỗi thì Helm tự rollback release.
resource "helm_release" "grafana" {
  name             = "grafana"
  namespace        = "monitoring"
  create_namespace = true
  # Chart grafana/grafana cũ đã deprecated (01/2026), chuyển sang grafana-community.
  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "grafana"
  version    = "13.5.0"
  values     = [file("${path.module}/values/grafana.yaml")]
  atomic     = true
  timeout    = 300
}

# Trạng thái release sau khi apply (deployed/failed).
output "grafana_release_status" {
  description = "Trạng thái Helm release"
  value       = helm_release.grafana.status
}
