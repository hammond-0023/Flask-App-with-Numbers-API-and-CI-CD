variable "subnet_id" {
  description = "The ID of the subnet where the instance will be launched"
  type        = string
  default     = "subnet-0f7936be912361044"
}

variable "db_password" {
  description = "The password for the database instance"
  type        = string
  default     = "HammondDB0023"
}

variable "vpc_id" {
  description = "main_vpc"
  type        = string
  default     = "vpc-08f5a497979062d22"
}

variable "hammond_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for HammondVPC"
}

variable "gateway_id" {
  description = "The ID of the internet gateway"
  type        = string
  default     = "igw-063618f01c8ce7996"
}