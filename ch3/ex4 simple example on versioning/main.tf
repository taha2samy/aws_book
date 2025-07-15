resource "aws_s3_bucket" "s3_log_storage_bucket" {
  bucket = "my-s3-logs-destination-bucket-unique-123456789"
  force_destroy = true
  versioning {
    enabled = true
  }
}
resource "aws_s3_bucket_object" "just_file" {
  bucket = aws_s3_bucket.s3_log_storage_bucket.id
  key    = "file.txt"
  content = "this version 1"
  
}
resource "aws_s3_bucket_object" "just_file_1" {
  bucket = aws_s3_bucket.s3_log_storage_bucket.id
  key    = "file.txt"
  content = "this version 2"
  
}

resource "aws_s3_bucket_object" "just_file_2" {
  bucket = aws_s3_bucket.s3_log_storage_bucket.id
  key    = "file.txt"
  content = "this version 3"
  
}

