# Exercise 1: S3 Fundamentals

**Duration**: 15-20 minutes
**Prerequisites**: LocalStack running, AWS CLI configured with localstack profile

**Note**: All commands below assume you've set `export AWS_PROFILE=localstack`. Alternatively, add `--profile localstack` to each command.

## Learning Objectives

By completing this exercise, you will:
- Create and manage S3 buckets
- Upload and retrieve objects from S3
- Configure bucket versioning for data protection
- Write and apply bucket policies for access control
- Understand the difference between bucket and object permissions

## Background

Amazon S3 (Simple Storage Service) is object storage built for storing and retrieving any amount of data. Key concepts:

- **Bucket**: Container for objects (files). Bucket names must be globally unique.
- **Object**: Files stored in buckets, identified by a key (path/filename).
- **Versioning**: Keep multiple versions of objects to protect against accidental deletion.
- **Bucket Policy**: JSON document that grants permissions to access bucket and objects.

## Tasks

### Task 1.1: Create an S3 Bucket

Create a bucket named `training-bucket-demo`.

```bash
aws s3 mb s3://training-bucket-demo
```

**Verify**:
```bash
aws s3 ls
```

You should see your bucket listed.

### Task 1.2: Upload Objects to S3

Create two test files and upload them to your bucket:

```bash
echo "This is a public file" > public-file.txt
echo "This is a private file" > private-file.txt

aws s3 cp public-file.txt s3://training-bucket-demo/public/public-file.txt
aws s3 cp private-file.txt s3://training-bucket-demo/private/private-file.txt
```

**Verify**:
```bash
aws s3 ls s3://training-bucket-demo/ --recursive
```

You should see both files in their respective prefixes.

### Task 1.3: Retrieve Objects from S3

Download one of the files to verify storage:

```bash
aws s3 cp s3://training-bucket-demo/public/public-file.txt downloaded-file.txt

cat downloaded-file.txt
```

You should see the original content.

### Task 1.4: Enable Versioning

Enable versioning to keep multiple versions of objects:

```bash
aws s3api put-bucket-versioning \
  --bucket training-bucket-demo \
  --versioning-configuration Status=Enabled
```

**Verify**:
```bash
aws s3api get-bucket-versioning \
  --bucket training-bucket-demo
```

Output should show: `"Status": "Enabled"`

**Test versioning** by uploading a modified file:
```bash
echo "This is an updated public file" > public-file.txt
aws s3 cp public-file.txt s3://training-bucket-demo/public/public-file.txt
```

List versions:
```bash
aws s3api list-object-versions \
  --bucket training-bucket-demo \
  --prefix public/public-file.txt
```

You should see two versions of the file.

### Task 1.5: Configure Bucket Policy for Public Read Access

Create a bucket policy that allows public read access to objects under the `public/` prefix only.

**Create a file named `bucket-policy.json`**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForPublicPrefix",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::training-bucket-demo/public/*"
    }
  ]
}
```


**Apply the policy**:
```bash
aws s3api put-bucket-policy \
  --bucket training-bucket-demo \
  --policy file://bucket-policy.json
```

**Verify the policy**:
```bash
aws s3api get-bucket-policy \
  --bucket training-bucket-demo
```

You should see your policy returned.

## Success Criteria

- [ ] S3 bucket created and listed successfully
- [ ] Two objects uploaded to different prefixes (public/, private/)
- [ ] Object successfully retrieved from S3
- [ ] Versioning enabled on the bucket
- [ ] Multiple versions visible after re-uploading the same file
- [ ] Bucket policy created allowing public read access to `public/*` only
- [ ] Policy successfully applied and verified

## Testing Your Work

Run the following commands to verify everything works:

```bash
aws s3 ls

aws s3 ls s3://training-bucket-demo/ --recursive

aws s3api get-bucket-versioning --bucket training-bucket-demo

aws s3api get-bucket-policy --bucket training-bucket-demo
```

## Common Pitfalls

1. **Bucket name conflicts**: If bucket creation fails, ensure the name is unique and hasn't been used before.

2. **Missing profile**: All AWS CLI commands must use `--profile localstack` (or have `AWS_PROFILE=localstack` set) to connect to LocalStack.

3. **Policy syntax errors**: JSON must be valid. Use a JSON validator if needed. Common issues:
   - Missing commas between elements
   - Incorrect bucket ARN format
   - Forgetting to replace placeholder bucket name

4. **File path issues**: When using `file://` in commands, ensure the JSON file exists in your current directory.

5. **Prefix confusion**: S3 doesn't have folders, only key prefixes. `public/file.txt` is one object key, not a folder structure.

## LocalStack-Specific Notes

- In real AWS, bucket names must be globally unique across all accounts. In LocalStack, they only need to be unique within your LocalStack instance.

- The bucket policy will only be enforced if `ENFORCE_IAM=1` is set in your LocalStack configuration (it is in this training).

- S3 URLs in LocalStack use path-style addressing: `http://localhost:4566/bucket-name/key` instead of virtual-hosted style used in real AWS.

## Key Concepts Review

- **Bucket**: Top-level container for objects
- **Object Key**: Full path to an object (e.g., `public/file.txt`)
- **Versioning**: Preserves all versions of an object for recovery
- **Bucket Policy**: Resource-based policy that grants access permissions
- **Principal**: Who is allowed access (`"*"` means everyone)
- **ARN**: Amazon Resource Name - unique identifier for AWS resources

## Next Steps

In Exercise 2, you'll create Lambda functions that can process events. Later, you'll combine S3 and Lambda to automatically process files when they're uploaded.
