# =============================================================================
# VÍ DỤ MINH HỌA: remote state trên Object Storage tương thích S3
# (ví dụ Object Storage của CMC, MinIO...). Chỉ chạy "terraform validate";
# muốn chạy thật cần endpoint + bucket + credential thật.
#
#   cd examples\remote-state-s3
#   terraform init -backend=false
#   terraform validate
# =============================================================================

terraform {
  # use_lockfile cần Terraform >= 1.10.
  required_version = "~> 1.16"

  backend "s3" {
    # Bucket chứa state (tạo sẵn ở stack 00-bootstrap, bật versioning).
    bucket = "idp-terraform-state"
    # Mỗi môi trường + mỗi stack một key -> một file state riêng.
    key = "dev/network/terraform.tfstate"
    # Backend s3 bắt buộc có region; với storage không phải AWS điền giá trị bất kỳ.
    region = "us-east-1"

    # Trỏ tới endpoint S3-compatible thay cho AWS.
    endpoints = {
      s3 = "https://s3.example.invalid" # [cần xác minh] endpoint Object Storage của CMC
    }
    use_path_style = true # nhiều storage S3-compatible chỉ hỗ trợ path-style

    # Bỏ các bước kiểm tra chỉ có ý nghĩa với AWS.
    skip_credentials_validation = true # không gọi AWS STS
    skip_region_validation      = true # region không có trong danh sách AWS
    skip_requesting_account_id  = true # không hỏi AWS account ID
    skip_metadata_api_check     = true # không gọi EC2 metadata
    skip_s3_checksum            = true # storage có thể không hỗ trợ checksum mới của AWS SDK

    # State locking bằng file .tflock cạnh state (ghi có điều kiện).
    # [cần xác minh] storage phải hỗ trợ conditional write; nếu không, dùng backend "pg".
    use_lockfile = true

    # KHÔNG ghi access key ở đây. Credential lấy từ biến môi trường:
    #   $env:AWS_ACCESS_KEY_ID = "..."; $env:AWS_SECRET_ACCESS_KEY = "..."
  }
}

# Một resource tối giản để có gì đó ghi vào state.
resource "terraform_data" "example" {
  input = "remote state demo"
}
