# Instead of $32/month NAT Gateway, i will use VPC endpoints

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  
  # Route table association
  route_table_ids = [
    aws_route_table.private.id,
    # aws_route_table.isolated.id
  ]
  
  # S3 endpoint is FREE
  tags = merge(var.tags, {
    Name = "${var.environment}-s3-endpoint"
  })
}



# I'm deleting this for now since i will use DOCKERHUB to pull images and eliminate the cost of using 
# This expensive endpoint  
/*
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  
  # Place in private subnets
  subnet_ids = aws_subnet.private[*].id
  
  security_group_ids = [aws_security_group.vpc_endpoint.id]
  
  # Interface endpoints have small cost but we'll manage it
  tags = merge(var.tags, {
    Name = "${var.environment}-ecr-api-endpoint"
  })
}*/ 
