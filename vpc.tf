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

data "aws_availability_zone" "subnet_az" {
  name = "us-west-1a"
}

# =========================
# Create your subnets here
# =========================

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = module.subnet_addrs.network_cidr_blocks["private"]
  tags = merge(module.label_vpc.tags, {
    "Name" = "private_subnet"
  })
  availability_zone = data.aws_availability_zone.subnet_az.name

}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = module.subnet_addrs.network_cidr_blocks["public"]
  map_public_ip_on_launch = true
  tags = merge(module.label_vpc.tags, {
    "Name" = "public_subnet"
  })
  availability_zone = data.aws_availability_zone.subnet_az.name
}

resource "aws_internet_gateway" "public_igw" {

  vpc_id = aws_vpc.main.id
  tags = merge(module.label_vpc.tags, {
    "Name" = "public_igw"
  })
}

resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_igw.id
  }
  tags = merge(module.label_vpc.tags, {
    "Name" = "public_route_table"
  })
}

resource "aws_route_table_association" "public_rt_association" {

  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id

}

resource "aws_route_table" "private_rt" {

  vpc_id = aws_vpc.main.id
  tags = merge(module.label_vpc.tags, {
    "Name" = "private_route_table"
  })
}

resource "aws_route_table_association" "private_rt_association" {

  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id

}

resource "aws_eip" "elastic-ip-nat-gw" {

  domain = "vpc"
  tags = merge(module.label_vpc.tags, {
    "Name" = "elastic-IP"
  })
}

resource "aws_nat_gateway" "nat-gw" {

  allocation_id = aws_eip.elastic-ip-nat-gw.id
  subnet_id     = aws_subnet.public_subnet.id

  depends_on = [aws_eip.elastic-ip-nat-gw]
  tags = merge(module.label_vpc.tags, {
    "Name" = "Nat-Gateway"
  })
}

resource "aws_route" "nat-gw-route" {
  route_table_id         = aws_route_table.private_rt.id
  nat_gateway_id         = aws_nat_gateway.nat-gw.id
  destination_cidr_block = aws_subnet.public_subnet.cidr_block
}

