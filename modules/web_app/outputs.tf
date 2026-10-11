# =============================================================================
# Output của module: những giá trị mà nơi gọi module có thể sử dụng tiếp
# (in ra màn hình, truyền sang module khác, đọc bằng terraform output...).
# =============================================================================

# URL truy cập ứng dụng.
output "url" {
  description = "URL truy cập web app"
  value       = "http://localhost:${var.external_port}"
}

# ID container - giá trị chỉ biết SAU khi apply ("known after apply" lúc plan).
output "container_id" {
  description = "ID của docker container"
  value       = docker_container.web.id
}

# Tên container, tiện cho các lệnh docker trong kịch bản demo.
output "container_name" {
  description = "Tên docker container"
  value       = docker_container.web.name
}
