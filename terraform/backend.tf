terraform {
  backend "s3" {
    bucket = "frontend-statefile"
    key    = "ecs/terraform.tfstate"
    region = "us-east-1"
  }
}
