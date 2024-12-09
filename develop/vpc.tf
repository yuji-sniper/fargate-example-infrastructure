# ===============================================================================
# main vpc
# ===============================================================================
resource "aws_vpc" "main" {
  cidr_block                       = "172.28.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name = "${local.project}-${local.env}"
  }
}

resource "aws_flow_log" "main_s3" {
  log_destination      = aws_s3_bucket.vpc_flow_log.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-${local.env}"
  }
}

resource "aws_route" "main_to_root" {
  route_table_id            = data.terraform_remote_state.root.outputs.route_table_id
  destination_cidr_block    = aws_vpc.main.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.root.id
}

resource "aws_vpc_peering_connection" "root" {
  peer_vpc_id = aws_vpc.main.id
  vpc_id      = data.terraform_remote_state.root.outputs.vpc_id
  auto_accept = true

  tags = {
    Name = "${local.project}-${local.env}-to-root-peering"
  }
}

# ===============================================================================
# public subnet
# ===============================================================================
resource "aws_subnet" "public" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.project}-${local.env}-public-${local.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  lifecycle {
    ignore_changes = [
      route,
    ]
  }

  tags = {
    Name = "${local.project}-${local.env}"
  }
}

resource "aws_route" "default_gw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "main" {
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ===============================================================================
# db subnet
# ===============================================================================
resource "aws_subnet" "db" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + length(local.availability_zones) * 2)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.project}-${local.env}-db-${local.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  lifecycle {
    ignore_changes = [
      route,
    ]
  }

  tags = {
    Name = "${local.project}-${local.env}-db"
  }
}

resource "aws_route_table_association" "db" {
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ===============================================================================
# elasticache subnet
# ===============================================================================
resource "aws_subnet" "elasticache" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + length(local.availability_zones) * 3)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.project}-${local.env}-elasticache-${local.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "elasticache" {
  vpc_id = aws_vpc.main.id

  lifecycle {
    ignore_changes = [
      route,
    ]
  }

  tags = {
    Name = "${local.project}-${local.env}-elasticache"
  }
}

resource "aws_route_table_association" "elasticache" {
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.elasticache[count.index].id
  route_table_id = aws_route_table.elasticache.id
}
