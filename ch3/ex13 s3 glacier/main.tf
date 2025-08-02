
resource "random_pet" "bucket_name" {
  prefix = "glacier-demo"
  length = 4
}

resource "aws_s3_bucket" "glacier_demo_bucket" {
   bucket = random_pet.bucket_name.id
}



resource "aws_s3_object" "instant_object" {
  bucket = aws_s3_bucket.glacier_demo_bucket.id
  key    = "tf-uploads/file-instant.txt"
  source = "file-instant.txt"
  
  storage_class = "GLACIER_IR"
  
}

resource "aws_s3_object" "flexible_object" {
  bucket = aws_s3_bucket.glacier_demo_bucket.id
  key    = "tf-uploads/file-flexible.txt"
  source = "file-flexible.txt"
  
  storage_class = "GLACIER"
  
}

resource "aws_s3_object" "deep_archive_object" {
  bucket = aws_s3_bucket.glacier_demo_bucket.id
  key    = "tf-uploads/file-deep.txt"
  source = "file-deep.txt"
  
  storage_class = "DEEP_ARCHIVE"
  
}

output "just" {
    value = "export BUCKET_NAME=${aws_s3_bucket.glacier_demo_bucket.id}"
  
}
output "aws_ls" {
    value = "aws s3 ls s3://${aws_s3_bucket.glacier_demo_bucket.id}/tf-uploads"
  
}