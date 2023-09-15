variable "datadog-app-key" {
  type = string
  sensitive = true
  }

variable "datadog-api-key" {
  type = string
  sensitive = true
  }

output "app-key" {
  value = var.datadog-app-key
  sensitive = true
  }

output "api-key" {
  value = var.datadog-api-key
  sensitive = true
  }

resource "null_resource" "datadog-app-key" {
  triggers = { 
    app-key = var.datadog-app-key
   }
  }   

resource "null_resource" "datadog-api-key" {
  triggers = { 
    api-key = var.datadog-api-key
   }
  }   
