# =============================================================================
# Module web_app: 1 network + 1 image nginx + 1 container.
# Khai báo provider của module nằm ở versions.tf.
# =============================================================================

# Network riêng cho mỗi app -> dev và prod tách biệt nhau
# (tương tự VPC/subnet riêng cho từng môi trường trên cloud).
resource "docker_network" "this" {
  name = "${var.app_name}-net"
}

# Image nginx. keep_locally = true: khi destroy KHÔNG xóa image khỏi máy,
# tránh ảnh hưởng container khác đang dùng chung image.
resource "docker_image" "nginx" {
  name         = "nginx:${var.image_tag}"
  keep_locally = true
}

# Container chạy nginx.
resource "docker_container" "web" {
  name  = "${var.app_name}-web"
  image = docker_image.nginx.image_id # Tham chiếu ngầm -> Terraform tự tạo image trước

  # Map cổng host -> cổng 80 của container.
  # Thay đổi external_port buộc Terraform phải TẠO LẠI container (-/+ replace).
  ports {
    internal = 80
    external = var.external_port
  }

  # Gắn container vào network của app.
  networks_advanced {
    name = docker_network.this.id
  }

  # Truyền biến môi trường; giá trị bí mật lấy từ biến sensitive.
  env = [
    "APP_ENV=${var.environment}",
    "API_TOKEN=${var.api_token}",
  ]

  # Ghi đè trang index.html để mở trình duyệt thấy ngay đang ở môi trường nào.
  upload {
    file    = "/usr/share/nginx/html/index.html"
    content = "<h1>Hello from ${upper(var.environment)}</h1><p>app=${var.app_name}, nginx:${var.image_tag}</p>\n"
  }

  # Label giúp lọc container: docker ps --filter label=managed-by=terraform
  labels {
    label = "managed-by"
    value = "terraform"
  }
  labels {
    label = "environment"
    value = var.environment
  }
}
