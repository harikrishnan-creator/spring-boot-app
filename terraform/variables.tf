variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-2"
}

variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
  default     = "springboot-eks-cluster"
}

variable "cluster_version" {
  type        = string
  description = "EKS Kubernetes Version"
  default     = "1.33"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR Block"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type = list(string)

  default = [
    "us-east-2a",
    "us-east-2b"
  ]
}

variable "public_subnets" {
  type = list(string)

  default = [
    "subnet-0185f8cff97957566",
    "subnet-0733023cbc2f2db21"
  ]
}

variable "private_subnets" {
  type = list(string)

  default = [
    "subnet-03c3c4f19e53580d0",
    "subnet-097099026c1415408"
  ]
}

variable "instance_types" {
  type = list(string)

  default = [
    "t3.small"
  ]
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 3
}
variable "disk_size" {
  type    = number
  default = 20
}
variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}
variable "vpc_id" {
  type    = string
  default = "vpc-003e0819192f784f9"
}
