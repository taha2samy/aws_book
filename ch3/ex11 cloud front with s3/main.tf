
locals {
  mime_types = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "png"  = "image/png"
    "ico"  = "image/x-icon"
  }
}
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "site_bucket" {
  bucket = "taha-secure-site-${random_id.bucket_suffix.hex}"
  force_destroy = true
  
}
resource "aws_s3_bucket_ownership_controls" "site_bucket_ownership" {
  bucket = aws_s3_bucket.site_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_public_access_block" "pab" {
  bucket = aws_s3_bucket.site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on = [ aws_s3_bucket_policy.s3_policy ]
}

resource "aws_s3_object" "site_files" {
  for_each = fileset("site/", "**/*")

  bucket       = aws_s3_bucket.site_bucket.id
  key          = each.value
  source       = "site/${each.value}"
  content_type   = lookup(local.mime_types, regex("\\.([^.]+)$", each.value)[0], "application/octet-stream")


}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "OAC for my secure site"
  description                       = "Origin Access Control for S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_cloudfront_distribution" "s3_distribution" {

  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_id                = "S3-Origin-for-my-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-Origin-for-my-site"
    viewer_protocol_policy = "redirect-to-https" 
    compress               = true
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
      lambda_function_association {
      event_type = "origin-response" 
      lambda_arn = aws_lambda_function.edge_header_adder.qualified_arn
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/error.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/error.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
    logging_config {
    bucket =aws_s3_bucket.site_bucket.bucket_regional_domain_name
    include_cookies = false
    prefix = "just_log/"
  }


  
  
}


data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
    statement {
    sid = "allow_add_logs_of_cloud_front"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.site_bucket.arn}/just_log/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
  

}

resource "aws_s3_bucket_policy" "s3_policy" {
  bucket = aws_s3_bucket.site_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}




output "secure_website_url" {
  description = "The secure HTTPS URL for the website."
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}