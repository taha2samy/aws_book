resource "aws_s3_bucket" "just_example" {
  bucket = "hallow-word-just-examples123"




}
resource "aws_s3_bucket_public_access_block" "public_read_access" {
  bucket = aws_s3_bucket.just_example.id

  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.just_example.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.just_example.arn}/*"
      }
    ]
  })
  depends_on = [ aws_s3_bucket.just_example,aws_s3_bucket_public_access_block.public_read_access ]
}