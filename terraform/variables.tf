variable "project_name" {
  default = "expense"
}
variable "environment" {
  default = "dev"
}
variable "common_tags" {
  default = {
    Project = "Expense"
    Environment = "dev"
    Terraform = true
    Component = "frontend"
  }
}
variable "zone_name" {
  default = "abhinavk.fun"
}
#created as part of CD
variable "app_version" {
  
}