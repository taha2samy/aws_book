resource "aws_s3_bucket" "my_s3_demo_bucket" {
  bucket = "my-unique-s3-flat-demo-bucket-123456789" 
  force_destroy = true # Allows deletion of non-empty bucket
}
resource "aws_s3_object" "just_a_file" {
  bucket = aws_s3_bucket.my_s3_demo_bucket.id
  key    = "just_a_file.txt"
  source = "${path.root}/just_a_file.txt"
  content_type = "text/plain"
}
resource "aws_s3_bucket_object" "just_a_content" {
  bucket = aws_s3_bucket.my_s3_demo_bucket.id
  key    = "justcontent/just_a_file.txt"
  content = "Just some content in a file"
}

output "bucket_name" {
  value = aws_s3_bucket.my_s3_demo_bucket.id
  
}