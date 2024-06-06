terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

provider "aws" {}

resource "aws_iam_user" "NettoramaS3User" {
  name = "NettoramaS3User"

  tags = {
    platform = "frends"
    integratie = "nettorama"
    deploymentType = "terraform"
    dateCreated = formatdate("D-MM-YYYY'T'hh:mm:ss", timestamp())
  }
}

resource "aws_iam_access_key" "NettoramaS3User" {
  user = aws_iam_user.NettoramaS3User.name
}

resource "aws_iam_policy" "NettoramaS3Policy" {
  name = "nettorama-policy"
  description = "policy for s3 access"
  #policy = "{\nVersion: 2012-10-17,\nStatement: [\n{\nEffect:\tAllow,\nAction:\t[\ns3:*,s3-object-lambda:*],Resource:arn:aws:s3:::tf-test*}"
  policy = "{\n\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Effect\": \"Allow\",\n\"Action\": [\n\"s3:*\",\n\"s3-object-lambda:*\"\n],\n\"Resource\": \"arn:aws:s3:::nettoramasyncflow0567*\"\n}\n]\n}"
}

resource "aws_iam_user_policy_attachment" "policy-attach" {
  user = aws_iam_user.NettoramaS3User.name
  policy_arn = aws_iam_policy.NettoramaS3Policy.arn
}

resource "aws_s3_bucket" "tf-test" {
    bucket = "tf-test"
}

resource "aws_s3_bucket_public_access_block" "tf-test_block_public_access" {
  bucket = aws_s3_bucket.terraform-test.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "tf-test_ownership" {
  bucket = aws_s3_bucket.terraform-test.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "tf-test_versioning" {
  bucket = aws_s3_bucket.tf-test.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tf-test_lifecycle-config" {
  depends_on = [ aws_s3_bucket_versioning.tf-test_versioning]

  bucket = aws_s3_bucket.tf-test.id

  rule {
    id = "RemoveAfter10-1"

    expiration {
      days = "10"
    }

    filter {
      prefix = "success/"
    }

    status = "Enabled"
  }

  rule {
    id = "RemoveAfter10-2"

    expiration {
      days = "10"
    }

    filter {
      prefix = "failed/"
    }

    status = "Enabled"
  }

}