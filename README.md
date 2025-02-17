# My multicloud as Code
Terraforming foundational infra for various projects.

## Prerequisites

- An AWS root account, organization, and Identity Access Management Instance
- An organization node under which sandbox accounts can be deployed.
- An Azure root account.
- State backend resources (below).

## Principles
- centralize IAM to this configuration as much as possible
- create a throwaway account / subscription for child terraform projects, and let terraform have ultimate access to those accounts

##  State backend

Chicken and egg. I don't cover the state bucket with terraform so that I can safely destroy this project. Deploy a bucket, object and dynamodb table and then provide a `state.config` file with the following parameters:

- `bucket`: The name of the S3 bucket where the Terraform state files will be stored.
- `key`: The path within the bucket where the state file will be stored.
- `region`: The AWS region where the S3 bucket is located.
- `profile`: The AWS CLI profile to use for accessing the S3 bucket.
- `use_lockfile`: A boolean indicating whether to use a lock file to prevent concurrent state operations.
- `dynamodb_table`: The name of the DynamoDB table to use for state locking.

Run `terraform init -backend-config="./state.config"` to initialize.