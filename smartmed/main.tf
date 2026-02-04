resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
   Name = "smartmed-vpc"
  }
}
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

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "smartmed-igw"
    }
}

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

resource "aws_security_group" "alb" {
  name = "smartmed-alb-sg"
  vpc_id = aws_vpc.vpc.id
  description = "Security group for ALB allowing HTTP and HTTPS traffic"
  tags = {
    Name = "smartmed-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name = "smartmed-app-sg"
  vpc_id = aws_vpc.vpc.id
  description = "Security group for App servers allowing traffic from ALB"
  tags = {
    Name = "smartmed-app-sg"
  }
}

resource "aws_security_group" "db" {
  name = "smartmed-db-sg"
  vpc_id = aws_vpc.vpc.id
  description = "Security group for DB servers allowing traffic from App servers"
  tags = {
    Name = "smartmed-db-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "alb_inbound_http" {
  security_group_id = aws_security_group.alb.id
  ip_protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4       = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_inbound_https" {
  security_group_id = aws_security_group.alb.id
  ip_protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4      = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_inbound_from_alb_http" {
  security_group_id        = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
}

resource "aws_vpc_security_group_ingress_rule" "app_inbound_from_alb_https" {
  security_group_id        = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
}

resource "aws_vpc_security_group_ingress_rule" "db_inbound_from_app" {
  security_group_id        = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
}
