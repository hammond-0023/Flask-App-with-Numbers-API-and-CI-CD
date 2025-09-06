terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.12.0"
    }
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-015cbce10f839bd0c"
  instance_type = "t2.micro"

  subnet_id         = var.subnet_id
  availability_zone = "eu-central-1a"

  tags = {
    Name = "AppServer"
  }
}