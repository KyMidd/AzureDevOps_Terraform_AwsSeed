##
# Module to build the Azure DevOps "seed" configuration
##

# Build an S3 bucket to store TF state
resource "aws_s3_bucket" "state_bucket" {
  bucket = "${var.name_of_s3_bucket}"

  # Tells AWS to encrypt the S3 bucket at rest by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  # Prevents Terraform from destroying or replacing this object - a great safety mechanism
  lifecycle {
    prevent_destroy = false
  }

  # Tells AWS to keep a version history of the state file
  versioning {
    enabled = true
  }

  tags = {
    BuiltBy = "Terraform"
  }
}

# Build a DynamoDB to use for terraform state locking
resource "aws_dynamodb_table" "tf_lock_state" {
  name         = "${var.dynamo_db_table_name}"

  # Pay per request is cheaper for low-i/o applications, like our TF lock state
  billing_mode = "PAY_PER_REQUEST"

  # Hash key is required, and must be an attribute
  hash_key     = "LockID"

  # Attribute LockID is required for TF to use this table for lock state
  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = "${var.dynamo_db_table_name}"
    BuiltBy = "Terraform"
  }
}

# Creates an IAM user for ADO to connect as - e.g., Authentication
resource "aws_iam_user" "ado_iam_user" {
  name = "${var.iam_user_name}"
  path = "/"

  tags = {
    BuiltBy = "Terraform"
  }
}

# Create an IAM role for ADO to assume when connecting
resource "aws_iam_role" "ado_iam_role" {
  name               = "${var.ado_iam_role_name}"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_user.ado_iam_user.arn}"
      },
      "Action": [
        "sts:AssumeRole"
      ]
    }
  ]
}
POLICY

  tags = {
    BuiltBy = "Terraform"
  }
}

# Create an IAM policy to list what ADO is able to do in AWS
resource "aws_iam_policy" "ado_iam_policy_permits" {
  name = "${var.aws_iam_policy_permits_name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AzureDevOpsPermitEc2",
      "Effect": "Allow",
      "Action": [
        "ec2:"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "AzureDevOpsPermitS3State",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.state_bucket.arn}/*"
      ]
    }
  ]
}
POLICY
}

# Attach the IAM policy to the role
resource "aws_iam_role_policy_attachment" "ado_iam_policy_permits_attach" {
  role       = "${aws_iam_role.ado_iam_role.name}"
  policy_arn = "${aws_iam_policy.ado_iam_policy_permits.arn}"
}

# Create IAM policy to allow ADO IAM user to assume ADO IAM role
resource "aws_iam_policy" "ado_iam_policy_assume_role" {
  name = "${var.aws_iam_policy_assume_name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAssumeRole",
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "${aws_iam_user.ado_iam_user.arn}"
    },
    {
      "Sid": "AllowAllActions",
      "Effect": "Allow",
      "Action": [
        "*"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

# Attach IAM assume role to User
resource "aws_iam_user_policy_attachment" "iam_user_assume_attach" {
  user       = "${aws_iam_user.ado_iam_user.name}"
  policy_arn = "${aws_iam_policy.ado_iam_policy_assume_role.arn}"
}
