# =============================================================================
# Pin version Terraform CLI + provider và cấu hình backend lưu state.
# =============================================================================

terraform {
  # Chỉ chấp nhận Terraform 1.x từ 1.16 trở lên -> cả team dùng cùng hành vi.
  required_version = "~> 1.16"

  # Provider Docker, cho phép 3.x nhưng không nhảy lên 4.0 (có thể breaking).
  # Version chính xác được khóa trong .terraform.lock.hcl (file này PHẢI commit).
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  # Backend local: state nằm ngay trong thư mục envs/prod.
  # Mỗi môi trường một thư mục -> một file state riêng -> plan/apply dev
  # không bao giờ chạm vào prod.
  # Thực tế trên cloud thay bằng backend "s3" (hoặc tương đương) có locking.
  backend "local" {
    path = "terraform.tfstate"
  }
}
