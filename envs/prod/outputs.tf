# =============================================================================
# Output của môi trường: chuyển tiếp output từ module ra ngoài
# để xem bằng "terraform output".
# =============================================================================

output "url" {
  description = "URL truy cập"
  value       = module.web_app.url
}

output "container_id" {
  description = "ID container"
  value       = module.web_app.container_id
}

output "container_name" {
  description = "Tên container"
  value       = module.web_app.container_name
}
