
locals {
  mime_types = {
    "html" = "text/html", "css" = "text/css", "js" = "application/javascript",
    "png" = "image/png", "jpg" = "image/jpeg", "svg" = "image/svg+xml"
  }
}

resource "aws_s3_bucket" "site_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "pab" {
  bucket = aws_s3_bucket.site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.site_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "PublicReadGetObject",
      Effect    = "Allow",
      Principal = "*",
      Action    = "s3:GetObject",
      Resource  = "${aws_s3_bucket.site_bucket.arn}/*"
    }]
  })
depends_on = [ aws_s3_bucket_public_access_block.pab ]
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.site_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_object" "site_files" {
  for_each = fileset("site/", "**/*")

  bucket       = aws_s3_bucket.site_bucket.id
  key          = each.value
  source       = "site/${each.value}"
  etag         = filemd5("site/${each.value}")
  content_type = lookup(local.mime_types, regex("\\.([^.]+)$", each.value)[0], "application/octet-stream")
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.website_config.website_endpoint
}