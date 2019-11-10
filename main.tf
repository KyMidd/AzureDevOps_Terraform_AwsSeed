# Require TF version to most recent
terraform {
  required_version = "=0.12.10"
}

# Download any stable version in AWS provider of 2.19.0 or higher in 2.19 train
provider "aws" {
  region  = "us-east-1"
  version = "~> 2.19.0"
}

# Call the seed_module to build our ADO seed info
module "ado_seed" {
  source                       = "./modules/ado_seed"
  name_of_s3_bucket            = "s3-bucket-name-kyler-ue1-tfstate"
  dynamo_db_table_name         = "aws-locks"
  iam_user_name                = "AzureDevOpsIamUser"
  ado_iam_role_name            = "AzureDevOpsIamRole"
  aws_iam_policy_permits_name  = "AzureDevOpsIamPolicyPermits"
  aws_iam_policy_assume_name   = "AzureDevOpsIamPolicyAssume"
}
