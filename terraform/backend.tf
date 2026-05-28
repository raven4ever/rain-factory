# POC: local backend with workspace-scoped state under terraform.tfstate.d/<workspace>/.
# Phase 5: switch to S3 + DynamoDB. Note: backend blocks cannot interpolate ${terraform.workspace};
# state separation under S3 requires workspace_key_prefix or partial -backend-config at init.
#
# Example S3 backend (uncomment + configure during Phase 5):
#
# terraform {
#   backend "s3" {
#     bucket               = "rain-factory-tfstate"
#     key                  = "rain-factory.tfstate"
#     workspace_key_prefix = "envs"
#     region               = "us-east-1"
#     dynamodb_table       = "rain-factory-tflock"
#     encrypt              = true
#   }
# }

terraform {
  backend "local" {}
}
