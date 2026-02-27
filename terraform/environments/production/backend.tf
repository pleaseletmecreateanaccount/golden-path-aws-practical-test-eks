terraform {
  backend "s3" {
    bucket         = "golden-path-tfstate-825566110381"
    key            = "production/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "golden-path-tfstate-lock"
    encrypt        = true
  }
}
