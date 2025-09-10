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

resource "aws_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Allow HTTP traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "hammond-db-subnet-group"
  subnet_ids = var.hammond_subnet_ids

  tags = {
    Name = "Hammond DB Subnet Group"
  }
}

resource "aws_elasticache_subnet_group" "cache_subnet_group" {
  name        = "cache-subnet-group"
  description = "Subnet group for ElastiCache"
  subnet_ids  = var.hammond_subnet_ids
}

resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "number-facts-cache"
  engine               = "redis"
  engine_version       = "6.x"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  subnet_group_name    = aws_elasticache_subnet_group.cache_subnet_group.name
}

resource "aws_db_subnet_group" "default" {
  name       = "my-db-subnet-group"
  subnet_ids = var.hammond_subnet_ids
  tags = {
    Name = "My DB Subnet Group"
  }
}


resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.gateway_id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = var.subnet_id
  route_table_id = aws_route_table.public.id
}


resource "aws_db_instance" "default" {
  identifier           = "hammond-db-instance"
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "factsDB"
  username             = "admin"
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot  = true
  publicly_accessible  = true

}

resource "aws_ecr_repository" "numbers_api" {
    name                 = "numbers-api"
    image_tag_mutability = "MUTABLE"
    image_scanning_configuration {
      scan_on_push = true
    }
  }

resource "aws_instance" "app_server2" {
  ami           = "ami-015cbce10f839bd0c"
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id
  availability_zone = "eu-central-1a"

  tags = {
    Name = "AppServer2"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              apt-get update
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              EOF

  
}

# Create IAM role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name        = "numbers-api-lambda-exec"
  description = "Execution role for numbers API Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "numbers-api-lambda-policy"
  description = "Policy for numbers API Lambda function"

  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
        Effect    = "Allow"
      },
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
        Effect    = "Allow"
      },
      {
        Action = [
          "rds-db:connect"
        ]
        Resource = aws_db_instance.default.arn
        Effect    = "Allow"
      },
      {
        Action = [
          "redis:*"
        ]
        Resource = aws_elasticache_cluster.cache.arn
        Effect    = "Allow"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "numbers_api" {
  filename      = "lambda_function.zip"
  function_name = "numbers-api-lambda"
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec.arn
  
  environment {
    variables = {
      DB_HOST     = aws_db_instance.default.address
      DB_USER     = "admin"
      DB_PASSWORD = var.db_password
      DB_NAME     = "factsDB"
    }
  }

  vpc_config {
    security_group_ids = [aws_security_group.app_sg.id]
    subnet_ids         = [var.subnet_id]
  }
}

resource "aws_api_gateway_rest_api" "numbers_api" {
  name        = "Numbers-API"
  description = "REST API for number facts"
}

resource "aws_api_gateway_resource" "facts_resource" {
  rest_api_id = aws_api_gateway_rest_api.numbers_api.id
  parent_id   = aws_api_gateway_rest_api.numbers_api.root_resource_id
  path_part   = "facts"
}

resource "aws_api_gateway_method" "get_facts" {
  rest_api_id   = aws_api_gateway_rest_api.numbers_api.id
  resource_id   = aws_api_gateway_resource.facts_resource.id
  http_method   = "GET"
  authorization = "NONE"
}