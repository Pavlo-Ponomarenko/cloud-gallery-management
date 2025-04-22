resource "aws_s3_bucket" "gallery_storage_bucket" {
  bucket = "images-cloud-storage"
  force_destroy = true
}