# Azure Configuration
variable "azure_tenant_id" {
  description = "Azure tenant ID (can be set via TF_VAR_azure_tenant_id environment variable)"
  type        = string
  sensitive   = true
}

variable "azure_subscription_id" {
  description = "Azure subscription ID (can be set via TF_VAR_azure_subscription_id environment variable)"
  type        = string
  sensitive   = true
}

# Azure DevOps Configuration
variable "azuredevops_org_service_url" {
  description = "Azure DevOps organization service URL (e.g., https://dev.azure.com/your-org)"
  type        = string
}

variable "azuredevops_personal_access_token" {
  description = "Azure DevOps Personal Access Token (can be set via TF_VAR_azuredevops_personal_access_token environment variable)"
  type        = string
  sensitive   = true
}

variable "azuredevops_project_name" {
  description = "Name for the Azure DevOps project to create"
  type        = string
  default     = "vault-integration"
}

variable "project_visibility" {
  description = "Visibility of the Azure DevOps project"
  type        = string
  default     = "private"
  validation {
    condition     = contains(["private", "public"], var.project_visibility)
    error_message = "Project visibility must be either 'private' or 'public'."
  }
}

# Service Connection Configuration
variable "service_endpoint_name" {
  description = "Name for the Azure DevOps service connection"
  type        = string
  default     = "AzureRM Service Connection for Vault with Automatic WIF"
}

# Optional Vault Configuration (can use environment variables instead)
variable "vault_address" {
  description = "HashiCorp Vault server address"
  type        = string
  default     = ""
}

variable "vault_token" {
  description = "HashiCorp Vault admin token"
  type        = string
  sensitive   = true
  default     = ""
}