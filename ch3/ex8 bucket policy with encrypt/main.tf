resource "aws_kms_key" "just_key" {

}
output "just_kms_key" {
  value = aws_kms_key.just_key.arn
}
resource "aws_s3_bucket" "encrypted_uploads_bucket" {
  bucket = "my-encrypted-uploads-bucket"
  force_destroy = true
  
}
resource "aws_s3_bucket_public_access_block" "just_example" {
  bucket = aws_s3_bucket.encrypted_uploads_bucket.id
  block_public_policy = false
  ignore_public_acls = false
}
resource "aws_s3_bucket_policy" "force_encryption_policy" {
  bucket = aws_s3_bucket.encrypted_uploads_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Deny",
        Principal = "*",
        Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.encrypted_uploads_bucket.arn}/hallow/world/*",
        Condition = {
  StringNotEquals = {
    "s3:x-amz-server-side-encryption" = "aws:kms"  
  }

        }
      }
    ]
  })
}