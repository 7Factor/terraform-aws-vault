resource "aws_s3_bucket" "vault" {
  bucket = var.vault_bucket_name
}
