resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.tags, {
    Name = "${var.Ambiente}-${var.Proyecto}-vpc"
    }
  )
}

resource "aws_subnet" "app" {
  for_each = var.subnet_numbers

  vpc_id = aws_vpc.main.id
  # availability_zone = each.key
  # las zone id se distribuyen random, falto fijarlas en la creacion
  availability_zone_id = "usw2-az${each.value}"
  cidr_block           = cidrsubnet(var.cidr, 4, each.value)
  tags = merge(local.flowlog-tags, {
    Name                              = "${var.Ambiente}-${var.Proyecto}-subnet-app${each.value}",
    "kubernetes.io/role/internal-elb" = 1
    }
  )
}
resource "aws_subnet" "public" {
  for_each = var.subnet_numbers

  vpc_id = aws_vpc.main.id
  #availability_zone = each.key
  availability_zone_id = "usw2-az${each.value}"
  cidr_block           = cidrsubnet(var.cidr, 10, each.value - 1)
  tags = merge(local.flowlog-tags, {
    Name                     = "${var.Ambiente}-${var.Proyecto}-subnet-public${each.value}",
    "kubernetes.io/role/elb" = 1
    }
  )
}
resource "aws_subnet" "datos" {
  for_each = var.subnet_numbers

  vpc_id = aws_vpc.main.id
  #availability_zone = each.key
  availability_zone_id = "usw2-az${each.value}"
  cidr_block           = cidrsubnet(var.cidr, 10, 3 + each.value)
  tags = merge(local.flowlog-tags, {
    Name = "${var.Ambiente}-${var.Proyecto}-subnet-datos${each.value}"
    }
  )
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${var.Ambiente}-${var.Proyecto}-igw"
    }
  )
}
resource "aws_eip" "nat-gw-ip" {
}
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat-gw-ip.id
  subnet_id     = aws_subnet.public["us-west-2a"].id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}
resource "aws_route_table" "rt-public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(local.tags, {
    Name = "rt-public-${var.Ambiente}-${var.Proyecto}"
    }
  )
}
resource "aws_route_table" "rt-private" {
  for_each = var.subnet_numbers
  vpc_id   = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gw.id
  }

  tags = merge(local.tags, {
    Name = "rt-private-${var.Ambiente}-${var.Proyecto}-${each.value}"
    }
  )
}
resource "aws_route_table_association" "rt-public" {
  for_each = var.subnet_numbers

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.rt-public.id
}
resource "aws_route_table_association" "rt-private-1" {
  for_each = var.subnet_numbers

  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.rt-private[each.key].id
}
