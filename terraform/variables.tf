variable "aws_region" {
  default = "us-east-1"
}

variable "app_name" {
  default = "react-frontend"
}

variable "docker_image" {
  description = "Docker image from Docker Hub"
  type        = string
}
