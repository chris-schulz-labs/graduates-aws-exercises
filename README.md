# AWS Training Program with LocalStack

## Overview

This training program provides hands-on experience with core AWS services for recent graduates who have academic AWS knowledge but no practical experience. The program uses LocalStack to simulate AWS services locally, allowing learners to experiment without incurring cloud costs.

**Duration**: 2-4 hours (practical portion)
**Approach**: Language-agnostic with Python examples

## Learning Path

The training consists of 6 progressive exercises that build upon each other:

1. **S3 Fundamentals** (15-20 min) - Object storage basics
2. **Lambda Basics** (20-25 min) - Serverless function fundamentals
3. **IAM Roles & Least Privilege** (20-25 min) - Security and permissions
4. **Lambda + S3 Event Processing** (25-30 min) - Event-driven architecture
5. **API Gateway + Lambda REST API** (25-30 min) - Building HTTP APIs
6. **SQS + Async Processing** (25-30 min) - Asynchronous messaging patterns

## Pre-Workshop Setup

### Prerequisites

- Docker and Docker Compose installed
- AWS CLI installed (v2 recommended)
- Python 3.8+ or Node.js 16+ (depending on preferred language)
- Text editor or IDE
- Terminal/command line access

### Setup Steps

1. **Clone/download the training materials**
   ```bash
   cd aws-training-poc
   ```

2. **Start LocalStack**
   ```bash
   docker-compose up -d
   ```

3. **Verify LocalStack is running**
   ```bash
   curl http://localhost:4566/_localstack/health
   ```

4. **Configure LocalStack for the AWS CLI**
   ```bash
   ./setup-profile.sh
   ```

5. **Test connectivity**
   ```bash
   aws s3 ls --profile localstack
   ```
### Troubleshooting

**LocalStack won't start**
- Check Docker is running: `docker ps`
- Check port 4566 is available: `lsof -i :4566`
- View logs: `docker logs aws-training-localstack`

**AWS CLI errors**
- Ensure `--profile localstack` is included in every command (or `AWS_PROFILE=localstack` is set)
- Verify profile configured: `aws configure list --profile localstack`
- Check LocalStack logs for service-specific errors

**Lambda functions fail**
- Ensure Docker socket mounted: check `docker-compose.yml` volumes
- Verify `LAMBDA_EXECUTOR=docker` in environment variables
- Check function logs: `aws logs tail /aws/lambda/<function-name> --profile localstack`

## Workshop Flow

### Recommended Structure

1. **Introduction (15 min)**
   - Overview of AWS services covered
   - LocalStack explanation and setup verification
   - Review of foundational concepts

2. **Exercise 1-3 (60-75 min)**
   - S3 fundamentals
   - Lambda basics
   - IAM roles and policies
   - Break after Exercise 3

3. **Exercise 4-5 (50-60 min)**
   - Lambda + S3 event processing
   - API Gateway + Lambda REST API
   - Break after Exercise 5

4. **Exercise 6 (25-30 min)**
   - SQS + async processing
   - Integration of all concepts

5. **Wrap-up (15 min)**
   - Review of key concepts
   - Real AWS differences
   - Next steps and resources

## LocalStack Compatibility Notes

### Services Used
- **S3**: Full support for buckets, objects, versioning, events
- **Lambda**: Docker executor required for function execution
- **IAM**: Optional enforcement in free tier (`ENFORCE_IAM=1`)
- **API Gateway**: V1 REST API supported (V2 HTTP API requires Pro)
- **SQS**: Full support including DLQ and message retention
- **CloudWatch Logs**: Logs stored and queryable in LocalStack

### Known Limitations
- Some advanced IAM policy conditions may not be enforced
- API Gateway custom domains require Pro
- Lambda layers work but require specific configuration
- No actual multi-region support (single endpoint)

### Configuration Reference

```yaml
environment:
  - SERVICES=s3,lambda,iam,apigateway,sqs,logs,sts
  - ENFORCE_IAM=1                    # Enable IAM permission checks
  - LAMBDA_EXECUTOR=docker           # Use Docker for Lambda execution
  - DEBUG=1                          # Verbose logging
  - AWS_DEFAULT_REGION=us-east-1     # Default region
```

## Additional Resources

### Documentation
- [LocalStack Documentation](https://docs.localstack.cloud)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

### Next Steps After Training
1. Experiment with other AWS services in LocalStack
2. Create a small project combining multiple services
3. Deploy a simple application to real AWS (Free Tier)
4. Learn about Infrastructure as Code (CloudFormation, Terraform)
5. Explore AWS SAM or Serverless Framework for deployment

## Support

For issues with:
- **LocalStack**: Check container logs and LocalStack documentation
- **AWS CLI**: Verify endpoint URL and credentials configuration
- **Exercise solutions**: Review solution code in each task's directory (e.g., `task-1/`, `task-2/`)
- **Concepts**: Refer to foundational concepts section above
