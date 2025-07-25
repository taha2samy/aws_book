generate key


```bash
KEY_B64=$(openssl rand -base64 32)
KEY_MD5=$(echo -n "$KEY_B64" | base64 -d | openssl dgst -md5 -binary | base64)
```

upload 

```bash
aws s3api put-object \
  --bucket my-unique-s3-flat-demo-bucket-123456789 \
  --key myfile.txt \
  --body ./just_a_file.txt \
  --sse-customer-algorithm AES256 \
  --sse-customer-key "$KEY_B64" \
  --sse-customer-key-md5 "$KEY_MD5"
```

download

```bash
aws s3api get-object \
  --bucket my-unique-s3-flat-demo-bucket-123456789 \
  --key myfile.txt \
  --sse-customer-algorithm AES256 \
  --sse-customer-key "$KEY_B64" \
  --sse-customer-key-md5 "$KEY_MD5" \
  ./downloaded_myfile.txt

```
