terraform {
  backend "s3" {
    bucket         = "your-tf-state-bucket"
    key            = "aws-lambda/dev/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-locks"
  }
}
