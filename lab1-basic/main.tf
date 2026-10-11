# =============================================================================
# Lab 1 - cơ bản: một file duy nhất chứa đủ 5 khái niệm
# Provider, Variable, Resource, Output (+ State sinh ra sau apply).
# =============================================================================

# Khai báo provider cần dùng. Provider Docker thuộc namespace kreuzwerker,
# thiếu khối này Terraform sẽ đi tìm hashicorp/docker và init lỗi.
# "~> 3.0" = từ 3.0 đến dưới 4.0; version chính xác ghi trong .terraform.lock.hcl.
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Cấu hình provider: trên Windows kết nối Docker Desktop qua named pipe.
provider "docker" {
  host = "npipe:////./pipe/docker_engine"
}

# Biến cổng: đổi port chỉ cần sửa giá trị, không phải sửa resource.
variable "external_port" {
  type    = number
  default = 8080
}

# Resource image nginx (pin tag, không dùng latest).
resource "docker_image" "nginx" {
  name = "nginx:1.27"
}

# Resource container. Tham chiếu docker_image.nginx.image_id tạo phụ thuộc ngầm:
# Terraform tạo image trước, container sau.
resource "docker_container" "web" {
  name  = "demo-nginx"
  image = docker_image.nginx.image_id

  # Đổi external là thay đổi "forces replacement" -> plan hiện -/+.
  ports {
    internal = 80
    external = var.external_port
  }
}

# Output in ra URL sau khi apply.
output "url" {
  value = "http://localhost:${var.external_port}"
}
