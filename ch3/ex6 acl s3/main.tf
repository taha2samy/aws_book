resource "aws_s3_bucket" "just_example" {
  bucket = "hallow-word-just-examples123"




}


resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.just_example.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
  
}
variable "aws_canonical_user_id" {
  default = ""
  
}

resource "aws_s3_bucket_public_access_block" "allow_access_to_public" {
  bucket = aws_s3_bucket.just_example.id
    block_public_acls       = false
    ignore_public_acls      = false
    
}
resource "aws_s3_bucket_acl" "allow_public_read" {
  bucket = aws_s3_bucket.just_example.id
  acl    = "private"
  depends_on = [ aws_s3_bucket_public_access_block.allow_access_to_public ]
  access_control_policy {
    grant {
      grantee {
        id   = var.aws_canonical_user_id
        type = "CanonicalUser"
      }
      permission = "READ"
    }

    grant {
      grantee {
        type = "Group"
        uri  = "http://acs.amazonaws.com/groups/s3/LogDelivery"
      }
      permission = "write"
    }

    owner {
      id = var.aws_canonical_user_id
    }
  }


}

resource "aws_s3_object" "file_private" {
  bucket = aws_s3_bucket.just_example.id
  
  key    = "just_prefix/private.txt"
  
  source = "private_file.txt" 
  
  acl    = "private"
  }

  resource "aws_s3_object" "file_public" {
  bucket = aws_s3_bucket.just_example.id
  
  key    = "just_prefix/public.txt"
  
  source = "public_file.txt" 

  }
  

  output "public_file_url" {
  description = "The public URL for the public file."
  value       = "https://${aws_s3_bucket.just_example.bucket}.s3.${aws_s3_bucket.just_example.region}.amazonaws.com/${aws_s3_object.file_public.key}"
}

output "private_file_url" {
  description = "The URL for the private file (should return Access Denied)."
  value       = "https://${aws_s3_bucket.just_example.bucket}.s3.${aws_s3_bucket.just_example.region}.amazonaws.com/${aws_s3_object.file_private.key}"
}

