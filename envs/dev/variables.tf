# =============================================================================
# Khai báo biến của root module. Giá trị thường gán trong terraform.tfvars;
# riêng secret gán qua biến môi trường TF_VAR_api_token (không commit).
# =============================================================================

# Địa chỉ Docker daemon. Windows: named pipe; Linux/CI: unix socket.
variable "docker_host" {
  description = "Docker daemon endpoint"
  type        = string
  default     = "npipe:////./pipe/docker_engine"
}

variable "app_name" {
  description = "Tên ứng dụng"
  type        = string
}

variable "environment" {
  description = "Tên môi trường"
  type        = string
}

variable "external_port" {
  description = "Cổng trên host"
  type        = number
}

variable "image_tag" {
  description = "Tag image nginx"
  type        = string
}

# Biến bí mật: KHÔNG có default, KHÔNG đặt trong tfvars.
# Gán bằng: $env:TF_VAR_api_token = "..."  (CI: lấy từ GitHub Secrets)
variable "api_token" {
  description = "Secret truyền vào container"
  type        = string
  sensitive   = true
}
