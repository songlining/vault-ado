# Generate random suffix for Service Principal name
resource "random_string" "sp_suffix" {
  length  = 8
  upper   = false
  special = false
}

# Get current Azure subscription and client config
data "azurerm_subscription" "current" {
  subscription_id = var.azure_subscription_id
}

data "azurerm_client_config" "current" {}

# Create Azure AD Application for passwordless authentication
resource "azuread_application" "vault_sp_app" {
  display_name = "vault-terraform-sp-${random_string.sp_suffix.result}"
  owners       = [data.azurerm_client_config.current.object_id]
  
  # Enable API access for Workload Identity Federation (passwordless)
  api {
    requested_access_token_version = 2
  }
  
  # Required API permissions for Azure Resource Manager integration
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }
}

# Create Service Principal
resource "azuread_service_principal" "vault_sp" {
  client_id                    = azuread_application.vault_sp_app.client_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]
}

# Create client secret for Vault Azure auth backend (in addition to WIF)
resource "azuread_application_password" "vault_sp_password" {
  application_id = azuread_application.vault_sp_app.id
  display_name   = "vault-auth-secret"
}

# Assign Owner role to Service Principal on the subscription
resource "azurerm_role_assignment" "vault_sp_owner" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.vault_sp.object_id
  
  depends_on = [azuread_service_principal.vault_sp]
}

# Create federated identity credential for passwordless Azure DevOps authentication
resource "azuread_application_federated_identity_credential" "vault_ado_federated_credential" {
  application_id = azuread_application.vault_sp_app.id
  display_name   = "azure-devops-workload-identity"
  description    = "Passwordless authentication between Azure DevOps and Azure using Workload Identity Federation"
  
  # Azure DevOps issuer pattern for federated authentication
  issuer              = "https://login.microsoftonline.com/${var.azure_tenant_id}/v2.0"
  subject             = azuredevops_serviceendpoint_azurerm.automatic.workload_identity_federation_subject
  audiences           = ["api://AzureADTokenExchange"]
  
  depends_on = [
    azuread_service_principal.vault_sp,
    azuredevops_project.vault_integration
  ]
}

# Wait for propagation
resource "time_sleep" "wait_for_sp_propagation" {
  depends_on = [
    azurerm_role_assignment.vault_sp_owner
  ]
  create_duration = "60s"
}