##
##  AWS general variables
##
variable "gen_region" {
  description = "AWS region to use"
  type        = string
}

variable "gen_environment" {
  description = "Prod, stage etc"
  type        = string
}

##
##  Networking
##
variable "net_vpc_id" {
  description = "VPC to deploy cluster to"
  type        = string
}

variable "net_task_subnet_ids" {
  description = "Subnets to deploy task into"
}

##
##  ECS cluster
##
variable "cluster_name" {
  description = "Name of existing ECS cluster to run task on"
  type        = string
}

variable "cluster_id" {
  description = "Id of existing ECS cluster to run task on"
  type        = string
}

##
##  Task
##
variable "task_name" {
  description = "name of task to run in ECS"
  type        = string
}

variable "task_cpu" {
  description = "CPU allocation for task"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "RAM allocation for task"
  type        = number
  default     = 512
}

variable "task_container_environment" {
  description = "ENV vars to inject into container environment"
  default     = []
}

variable "task_container_image" {
  type = string
}

variable "task_container_image_tag" {
  type    = string
  default = "latest"
}

variable "task_container_port" {
  description = "Port to expose for container"
  type        = number
  default     = 80
}

##
##  Service
##
variable "service_addition_sg_ids" {
  description = "Additional security group IDs to associate with the service"
  type        = list(any)
  default     = []
}

##
##  Scaling
##

variable "scaling_min_capacity" {
  description = "Number of containers to run. Also used for autoscaling min capacity"
  type        = number
  default     = 2
}

variable "scaling_max_capacity" {
  description = "Max size to autoscale to"
  type        = number
  default     = 4
}
