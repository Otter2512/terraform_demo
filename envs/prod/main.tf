# =============================================================================
# Root module của môi trường PROD: cấu hình provider và gọi module web_app.
# =============================================================================

# Cấu hình provider Docker. Mặc định kết nối Docker Desktop trên Windows
# qua named pipe; CI (Linux) ghi đè bằng biến docker_host.
provider "docker" {
  host = var.docker_host
}

# Gọi module dùng chung. Mọi giá trị riêng của prod đến từ terraform.tfvars.
module "web_app" {
  source = "../../modules/web_app"

  app_name      = var.app_name
  environment   = var.environment
  external_port = var.external_port
  image_tag     = var.image_tag
  api_token     = var.api_token
}
