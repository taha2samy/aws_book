resource "aws_s3_bucket" "s3_log_storage_bucket" {
  bucket = "my-s3-logs-destination-bucket-unique-123456789"
  force_destroy = true
}

resource "aws_s3_bucket" "s3_source_data_bucket" {
  bucket = "my-s3-source-data-bucket-unique-123456789"
  force_destroy = true
}

resource "aws_s3_bucket_logging" "source_bucket_access_logging" {
  bucket        = aws_s3_bucket.s3_source_data_bucket.id
  target_bucket = aws_s3_bucket.s3_log_storage_bucket.id
  target_prefix = "s3-access-logs/"
}
resource "aws_s3_bucket_object" "upload_file_as_example" {
  bucket = aws_s3_bucket.s3_source_data_bucket.id
  key    = "file.txt"
  content = "This is an example file for S3 access logging."
  
}
resource "aws_s3_bucket_policy" "allow_s3_logging" {
  bucket = aws_s3_bucket.s3_log_storage_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "S3ServerAccessLogsPolicy",
        Effect = "Allow",
        Principal = {
          Service = "logging.s3.amazonaws.com"
        },
        Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.s3_log_storage_bucket.arn}/*"
      }
    ]
  })
}
output "s3_log_storage_bucket_name" {
  value = aws_s3_bucket.s3_log_storage_bucket.id
  
}