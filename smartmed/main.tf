# Terraform configuration for SmartMed application infrastructure on AWS

# This configuration sets up a VPC with public and private subnets, an Internet Gateway, a NAT Gateway, route tables, security groups, and an S3 bucket for asset storage. The S3 bucket is configured with versioning, server-side encryption using KMS, public access block settings, and a lifecycle policy to transition objects to Glacier after 30 days.

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
   Name = "smartmed-vpc"
  }
}

# Create public and private subnets in different availability zones for high availability
resource "aws_subnet" "public_subnet_1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24" 
    availability_zone = "us-east-1a"
    tags = {
        Name = "pub-subnet-1"
    } 
}

resource "aws_subnet" "public_subnet_2" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.2.0/24" 
    availability_zone = "us-east-1b"
    tags = {
        Name = "pub-subnet-2"
    } 
}

resource "aws_subnet" "private_subnet_1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.3.0/24" 
    availability_zone = "us-east-1a"
    tags = {
        Name = "priv-subnet-1"
    } 
}

resource "aws_subnet" "private_subnet_2" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.4.0/24" 
    availability_zone = "us-east-1b"
    tags = {
        Name = "priv-subnet-2"
    } 
}

# Internet Gateway for public subnet access to the internet
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "smartmed-igw"
    }
}

# Allocate an Elastic IP for the NAT Gateway
resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = {
    Name = "smartmed-nat-gw"
  }
}

# Route tables for public and private subnets
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "smartmed-public-rt"
    }
}

resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gw.id
    }
    tags = {
        Name = "smartmed-private-rt"
    }
}

# Associate route tables with subnets
resource "aws_route_table_association" "public_subnet_1_association" {
    subnet_id = aws_subnet.public_subnet_1.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
    subnet_id = aws_subnet.public_subnet_2.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_1_association" {
    subnet_id = aws_subnet.private_subnet_1.id
    route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
    subnet_id = aws_subnet.private_subnet_2.id
    route_table_id = aws_route_table.private_rt.id
}

# Security group for ALB allowing HTTP and HTTPS traffic
resource "aws_security_group" "alb" {
  name = "smartmed-alb-sg"
  vpc_id = aws_vpc.vpc.id
  description = "Security group for ALB allowing HTTP and HTTPS traffic"
  tags = {
    Name = "smartmed-alb-sg"
  }
}

# Security group for App servers allowing traffic from ALB
resource "aws_security_group" "app" {
  name = "smartmed-app-sg"
  vpc_id = aws_vpc.vpc.id
  description = "Security group for App servers allowing traffic from ALB"
  tags = {
    Name = "smartmed-app-sg"
  }
}

# Security group for DB servers allowing traffic from App servers
resource "aws_security_group" "db" {
  name = "smartmed-db-sg"
  vpc_id = aws_vpc.vpc.id
  description = "Security group for DB servers allowing traffic from App servers"
  tags = {
    Name = "smartmed-db-sg"
  }
}

# Allow inbound HTTP traffic to ALB from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_inbound_http" {
  security_group_id = aws_security_group.alb.id
  ip_protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4       = "0.0.0.0/0"
}

# Allow inbound HTTPS traffic to ALB from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_inbound_https" {
  security_group_id = aws_security_group.alb.id
  ip_protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4      = "0.0.0.0/0"
}

# Allow ALB to communicate with app servers on port 80 (HTTP) and 443 (HTTPS)
resource "aws_vpc_security_group_ingress_rule" "app_inbound_from_alb_http" {
  security_group_id        = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
}

# Allow ALB to communicate with app servers on port 443 for secure traffic
resource "aws_vpc_security_group_ingress_rule" "app_inbound_from_alb_https" {
  security_group_id        = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
}

# Allow app servers to communicate with DB servers on port 5432 (PostgreSQL)
resource "aws_vpc_security_group_ingress_rule" "db_inbound_from_app" {
  security_group_id        = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
}
# s3 bucket for storing assets with versioning, encryption, public access block, and lifecycle configuration
resource "aws_s3_bucket" "smartmed_bucket" {
  bucket = "smartmed-assets"
  tags = {
    Name = "smartmed-assets"
  }
}
# Enable versioning on the S3 bucket
resource "aws_s3_bucket_versioning" "smartmed_versioning" {
  bucket = aws_s3_bucket.smartmed_bucket.id
  versioning_configuration {
    status = "Enabled"
  } 
}

# KMS key for encrypting S3 bucket objects
resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

# Server-side encryption configuration for the S3 bucket using KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "smartmed_encryption" {
  bucket = aws_s3_bucket.smartmed_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.mykey.arn
    }
  }
}

# Public access block configuration to prevent public access to the bucket
resource "aws_s3_bucket_public_access_block" "smartmed_public_access_block" {
  bucket = aws_s3_bucket.smartmed_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration to transition objects to Glacier after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "smartmed_lifecycle" {
  bucket = aws_s3_bucket.smartmed_bucket.id

  rule {
    id = "glacier-transition"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}

#CloudFront distribution for serving assets from S3 with OAI for secure access

# CloudFront Origin Access Identity for secure S3 access
resource "aws_cloudfront_origin_access_identity" "smartmed_oai" {
  comment = "OAI for smartmed S3 bucket"
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "smartmed_bucket_policy" {
  bucket = aws_s3_bucket.smartmed_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.smartmed_oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.smartmed_bucket.arn}/*"
      }
    ]
  })
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "smartmed_distribution" {
  enabled = true
  is_ipv6_enabled = true

  origin {
    domain_name = aws_s3_bucket.smartmed_bucket.bucket_regional_domain_name
    origin_id   = "smartmedS3Origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.smartmed_oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "smartmedS3Origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "smartmed-distribution"
  }
}


