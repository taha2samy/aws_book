
resource "aws_s3_bucket" "my_s3_demo_bucket" {
  bucket = "my-unique-s3-flat-demo-bucket-123456789" 
}
resource "aws_s3_bucket_server_side_encryption_configuration" "encrypt_s3" {
  
  bucket = aws_s3_bucket.my_s3_demo_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_object" "send_file" {
  
  bucket = aws_s3_bucket.my_s3_demo_bucket.id
  key    = "file.txt"
  source = "${path.root}/just_a_file.txt"
  content_type = "text/plain"
}