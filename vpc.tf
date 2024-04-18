module "label_vpc" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "vpc"
  attributes = ["main"]

}

module "subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.vpc_cidr
  networks = [
    {
      name     = "private"
      new_bits = 4
    },
    {
      name     = "public"
      new_bits = 4
    }
  ]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = module.label_vpc.tags
}

# =========================
# Create your subnets here
# =========================

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = module.subnet_addrs.network_cidr_blocks["private"]
  tags = {
    Name = "private_subnet"
  }

}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = module.subnet_addrs.network_cidr_blocks["public"]
  tags = {
    Name = "public_subnet"
  }
}

resource "aws_internet_gateway" "test_igw" {

  vpc_id = aws_vpc.main.id

}

resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test_igw.id
  }

}

resource "aws_route_table_association" "public_rt_association" {

  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id

}

resource "aws_route_table" "private_rt" {

  vpc_id = aws_vpc.main.id
  route {
    cidr_block = var.vpc_cidr
  }

}

resource "aws_route_table_association" "private_rt_association" {

  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id

}

