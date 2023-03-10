variable "path" { }
variable "mutable_secrets" { 
  type = map(string)
  sensitive   = true
  default = {}
}
variable "immutable_secrets" { 
  type = map(string)
  sensitive   = true
  default = {}
}
