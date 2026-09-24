variable "base_name" {
  description = "Base name for resources"
  type        = string
}

/* variable "http_port" {
  description = "Port for HTTP traffic"
  type        = number
} */

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
}