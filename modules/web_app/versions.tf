# =============================================================================
# Module con cũng PHẢI tự khai báo required_providers (chỉ source + version).
# Thiếu khối này, init sẽ đi tìm hashicorp/docker và lỗi.
# Module KHÔNG khai báo block provider - root module (envs/*) quyết định
# kết nối tới đâu.
# =============================================================================

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
