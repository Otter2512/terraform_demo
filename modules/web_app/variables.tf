# =============================================================================
# Biến đầu vào (input) của module web_app.
# Module không tự biết mình chạy ở dev hay prod - mọi khác biệt đều truyền vào
# qua các biến dưới đây. Đây là chìa khóa để TÁI SỬ DỤNG module.
# =============================================================================

# Tên ứng dụng: dùng làm tiền tố cho tên network và container.
# Validation chỉ cho phép chữ thường, số, dấu gạch ngang (tên hợp lệ cho Docker).
variable "app_name" {
  description = "Tên ứng dụng, dùng đặt tên network/container"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.app_name))
    error_message = "app_name chỉ gồm a-z, 0-9, dấu '-' và dài 3-30 ký tự."
  }
}

# Cổng trên máy host map vào cổng 80 của nginx.
# Validation: chặn cổng đặc quyền (<1024) và giá trị ngoài phạm vi TCP.
# Terraform sẽ báo lỗi ngay ở bước plan, trước khi đụng vào hạ tầng.
variable "external_port" {
  description = "Cổng trên host (1024-65535)"
  type        = number

  validation {
    condition     = var.external_port >= 1024 && var.external_port <= 65535 && floor(var.external_port) == var.external_port
    error_message = "external_port phải là số nguyên trong khoảng 1024-65535."
  }
}

# Tag của image nginx. Pin tag cụ thể (không dùng "latest") để mọi lần apply
# đều cho ra cùng một kết quả.
variable "image_tag" {
  description = "Tag của image nginx, ví dụ 1.27"
  type        = string
  default     = "1.27"
}

# Tên môi trường, chỉ dùng để hiển thị trên trang web và gắn label.
variable "environment" {
  description = "Tên môi trường (dev/prod)"
  type        = string
}

# Ví dụ biến bí mật: sensitive = true khiến Terraform che giá trị trong
# output của plan/apply (hiện "(sensitive value)").
# LƯU Ý: giá trị vẫn được lưu DẠNG RÕ trong file state -> state phải được bảo vệ.
variable "api_token" {
  description = "Chuỗi bí mật truyền vào container qua biến môi trường"
  type        = string
  sensitive   = true
}
