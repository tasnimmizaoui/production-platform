# 7. ROUTE TABLES with security-focused routing
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(var.tags, {
    Name = "${var.environment}-public-rt"
  })
}

# Private Route Table (NO NAT - uses VPC endpoints)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Internal routes only
  
  tags = merge(var.tags, {
    Name = "${var.environment}-private-rt"
    Description = "No internet access - uses VPC endpoints"
  })
}

# Isolated Route Table (most restrictive)
/*
resource "aws_route_table" "isolated" {
  count = var.create_isolated_subnets ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  # No routes at all - completely isolated
  # Future: peering connections if needed
  
  tags = merge(var.tags, {
    Name = "${var.environment}-isolated-rt"
  })
}*/

# 8. ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

/*
resource "aws_route_table_association" "isolated" {
  count = var.create_isolated_subnets ? length(aws_subnet.isolated) : 0
  
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated[0].id
}*/
