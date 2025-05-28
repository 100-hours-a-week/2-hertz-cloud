resource "aws_route_table" "this" {
  vpc_id = var.vpc_id

  tags = {
    Name      = "${var.env}-${var.is_public ? "public" : "private"}-rtb"
    Component = var.is_public ? "public-route-table" : "private-route-table"
  }
}

resource "aws_route" "public" { # public 전용
  count = var.is_public ? 1 : 0

  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.igw_id
}

resource "aws_route" "private" { # nat 전용
  count = var.is_public ? 0 : 1

  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_id
}