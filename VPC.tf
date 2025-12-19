# Get Availability Zones
data "aws_availability_zones" "available" {
  provider = aws.mumbai
  state    = "available"
}

# VPC
resource "aws_vpc" "main" {
  provider             = aws.mumbai
  cidr_block           = "10.11.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "FVRK-DEV-VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  provider = aws.mumbai
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "FVRK-DEV-IGW"
  }
}

# Public Subnets (0-3)
resource "aws_subnet" "public" {
  count                   = 4
  provider                = aws.mumbai
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "FVRK-DEV-public-subnet-${count.index + 1}"
  }
}

# Private Subnets (4-7)
resource "aws_subnet" "private" {
  count             = 4
  provider          = aws.mumbai
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + 4)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "FVRK-DEV-private-subnet-${count.index + 1}"
  }
}

# Route Table - Public
resource "aws_route_table" "public" {
  provider = aws.mumbai
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "FVRK-DEV-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  count          = 4
  provider       = aws.mumbai
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table - Private
resource "aws_route_table" "private" {
  provider = aws.mumbai
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "FVRK-DEV-private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  count          = 4
  provider       = aws.mumbai
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}