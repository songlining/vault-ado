terraform {
  required_providers {
    azuredevops = {
      source = "microsoft/azuredevops"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
    vault = {
      source = "hashicorp/vault"
    }
    random = {
      source = "hashicorp/random"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}


provider "azuredevops" {
  org_service_url       = var.azuredevops_org_service_url
  personal_access_token = var.azuredevops_personal_access_token
}

provider "azuread" {
  tenant_id = var.azure_tenant_id
}

provider "azurerm" {
  features {}
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
}

provider "vault" {
  # Set VAULT_ADDR and VAULT_TOKEN environment variables
  # Or use variables if preferred
}

# Create Azure DevOps Service Connection using passwordless Workload Identity Federation
resource "azuredevops_serviceendpoint_azurerm" "automatic" {
  project_id                             = azuredevops_project.vault_integration.id
  service_endpoint_name                  = var.service_endpoint_name
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation" # No secrets required
  azurerm_spn_tenantid                   = var.azure_tenant_id
  azurerm_subscription_id                = var.azure_subscription_id
  azurerm_subscription_name              = data.azurerm_subscription.current.display_name
  
  # Only requires Service Principal ID - no secrets needed for WIF
  credentials {
    serviceprincipalid = azuread_application.vault_sp_app.client_id
  }
  
  depends_on = [
    azuredevops_project.vault_integration,
    time_sleep.wait_for_sp_propagation
  ]
}