# VPC Lattice Configuration for Cross-Account Database Access
# This Terraform configuration sets up VPC Lattice for optimized database connectivity

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "database_account_id" {
  description = "AWS account ID where database resides"
  type        = string
}

variable "application_account_id" {
  description = "AWS account ID where applications run"
  type        = string
}

variable "database_vpc_id" {
  description = "VPC ID where database is located"
  type        = string
}

variable "application_vpc_id" {
  description = "VPC ID where applications are located"
  type        = string
}

variable "database_subnet_ids" {
  description = "Subnet IDs where database instances are located"
  type        = list(string)
}

# Provider configuration
provider "aws" {
  region = var.region
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_vpc" "database" {
  id = var.database_vpc_id
}

data "aws_vpc" "application" {
  id = var.application_vpc_id
}

# VPC Lattice Service Network
resource "aws_vpclattice_service_network" "database_network" {
  name      = "database-service-network"
  auth_type = "AWS_IAM"

  tags = {
    Name        = "Database Service Network"
    Environment = "production"
    Purpose     = "cross-account-database-access"
  }
}

# VPC Lattice Service for Database
resource "aws_vpclattice_service" "database_service" {
  name               = "database-service"
  custom_domain_name = "db.internal.company.com"
  auth_type          = "AWS_IAM"

  tags = {
    Name        = "Database Service"
    Environment = "production"
    Purpose     = "database-access"
  }
}

# Target Group for Database Instances
resource "aws_vpclattice_target_group" "database_targets" {
  name = "database-target-group"
  type = "IP"

  config {
    port             = 5432
    protocol         = "TCP"
    vpc_identifier   = var.database_vpc_id
    protocol_version = "TCP"
    
    health_check {
      enabled                       = true
      health_check_grace_period_seconds = 30
      health_check_interval_seconds     = 30
      health_check_timeout_seconds      = 5
      healthy_threshold_count           = 2
      unhealthy_threshold_count         = 2
      protocol                          = "TCP"
      port                              = 5432
    }
  }

  tags = {
    Name        = "Database Target Group"
    Environment = "production"
  }
}

# Service Network Service Association
resource "aws_vpclattice_service_network_service_association" "database_association" {
  service_identifier         = aws_vpclattice_service.database_service.id
  service_network_identifier = aws_vpclattice_service_network.database_network.id

  tags = {
    Name = "Database Service Association"
  }
}

# Listener for Database Service
resource "aws_vpclattice_listener" "database_listener" {
  name               = "database-tcp-listener"
  protocol           = "TCP"
  service_identifier = aws_vpclattice_service.database_service.id

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.database_targets.id
        weight                  = 100
      }
    }
  }

  port = 5432

  tags = {
    Name = "Database TCP Listener"
  }
}

# VPC Association for Database VPC
resource "aws_vpclattice_service_network_vpc_association" "database_vpc_association" {
  vpc_identifier             = var.database_vpc_id
  service_network_identifier = aws_vpclattice_service_network.database_network.id
  security_group_ids         = [aws_security_group.vpc_lattice_database.id]

  tags = {
    Name = "Database VPC Association"
  }
}

# VPC Association for Application VPC (if in same account)
resource "aws_vpclattice_service_network_vpc_association" "application_vpc_association" {
  count = var.database_account_id == var.application_account_id ? 1 : 0
  
  vpc_identifier             = var.application_vpc_id
  service_network_identifier = aws_vpclattice_service_network.database_network.id
  security_group_ids         = [aws_security_group.vpc_lattice_application.id]

  tags = {
    Name = "Application VPC Association"
  }
}

# Security Group for VPC Lattice in Database VPC
resource "aws_security_group" "vpc_lattice_database" {
  name_prefix = "vpc-lattice-database-"
  vpc_id      = var.database_vpc_id
  description = "Security group for VPC Lattice database access"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.application.cidr_block]
    description = "PostgreSQL access from application VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "VPC Lattice Database Security Group"
  }
}

# Security Group for VPC Lattice in Application VPC
resource "aws_security_group" "vpc_lattice_application" {
  name_prefix = "vpc-lattice-application-"
  vpc_id      = var.application_vpc_id
  description = "Security group for VPC Lattice application access"

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.database.cidr_block]
    description = "PostgreSQL access to database VPC"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for VPC Lattice API calls"
  }

  tags = {
    Name = "VPC Lattice Application Security Group"
  }
}

# IAM Policy for Cross-Account Access
resource "aws_vpclattice_auth_policy" "cross_account_access" {
  resource_identifier = aws_vpclattice_service_network.database_network.arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.application_account_id}:root"
        }
        Action = [
          "vpc-lattice:Invoke"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "vpc-lattice:ServiceNetwork" = aws_vpclattice_service_network.database_network.arn
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for VPC Lattice Access Logs
resource "aws_cloudwatch_log_group" "vpc_lattice_logs" {
  name              = "/aws/vpclattice/database-service-network"
  retention_in_days = 30

  tags = {
    Name        = "VPC Lattice Access Logs"
    Environment = "production"
  }
}

# Access Logging Configuration
resource "aws_vpclattice_access_log_subscription" "database_network_logs" {
  resource_identifier = aws_vpclattice_service_network.database_network.arn
  
  destination_arn = aws_cloudwatch_log_group.vpc_lattice_logs.arn

  tags = {
    Name = "Database Network Access Logs"
  }
}

# Outputs
output "service_network_arn" {
  description = "ARN of the VPC Lattice service network"
  value       = aws_vpclattice_service_network.database_network.arn
}

output "service_network_id" {
  description = "ID of the VPC Lattice service network"
  value       = aws_vpclattice_service_network.database_network.id
}

output "database_service_arn" {
  description = "ARN of the database service"
  value       = aws_vpclattice_service.database_service.arn
}

output "database_service_dns_name" {
  description = "DNS name of the database service"
  value       = aws_vpclattice_service.database_service.dns_entry[0].domain_name
}

output "target_group_arn" {
  description = "ARN of the database target group"
  value       = aws_vpclattice_target_group.database_targets.arn
}

output "security_group_database_id" {
  description = "ID of the database security group"
  value       = aws_security_group.vpc_lattice_database.id
}

output "security_group_application_id" {
  description = "ID of the application security group"
  value       = aws_security_group.vpc_lattice_application.id
}
