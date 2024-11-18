output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr_block" {
  value = aws_vpc.main.cidr_block
}

output "route_table_id" {
  value = aws_route_table.public.id
}

output "zone_id" {
  value = aws_route53_zone.main.id
}

output "bastion_security_group_id" {
  value = aws_security_group.bastion.id
}
