output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = var.vpc_id
}

output "private_subnets" {
  value = var.private_subnets
}
