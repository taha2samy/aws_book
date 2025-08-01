resource "aws_lambda_function" "edge_header_adder" {
  provider = aws.just_name_region
  function_name = "edge-header-adder-${random_id.bucket_suffix.hex}"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  handler = "just_add_header.handler" 
  runtime = "nodejs18.x"
  role    = aws_iam_role.lambda_edge_role.arn
  publish = true 
}
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/aws_edge_lambda/just_add_header.js"  
  output_path = "${path.module}/aws_edge_lambda/lambda_payload.zip"    
}

resource "aws_iam_role_policy_attachment" "lambda_edge_logs" {
  provider = aws.just_name_region
  role       = aws_iam_role.lambda_edge_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "lambda_edge_role" {
  provider = aws.just_name_region
  name = "iam-role-for-lambda-edge-${random_id.bucket_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}
