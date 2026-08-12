terraform {
  backend "s3" {
    bucket         = "hari-terraform-state-bucket-20260812"
    key            = "eks/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
