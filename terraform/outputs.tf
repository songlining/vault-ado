output "azuredevops_project_id" {
  description = "ID of the created Azure DevOps project"
  value       = azuredevops_project.vault_integration.id
}

output "azuredevops_project_name" {
  description = "Name of the created Azure DevOps project"
  value       = azuredevops_project.vault_integration.name
}

output "azuredevops_project_url" {
  description = "URL of the created Azure DevOps project"
  value       = "${var.azuredevops_org_service_url}/${azuredevops_project.vault_integration.name}"
}

output "git_repository_id" {
  description = "ID of the created Git repository"
  value       = azuredevops_git_repository.vault_integration_repo.id
}

output "git_repository_url" {
  description = "Clone URL of the created Git repository"
  value       = azuredevops_git_repository.vault_integration_repo.remote_url
}

output "build_pipeline_id" {
  description = "ID of the created build pipeline"
  value       = azuredevops_build_definition.vault_integration_pipeline.id
}

output "service_connection_id" {
  description = "ID of the created Azure DevOps service connection"
  value       = azuredevops_serviceendpoint_azurerm.automatic.id
}

output "service_connection_name" {
  description = "Name of the created Azure DevOps service connection"
  value       = azuredevops_serviceendpoint_azurerm.automatic.service_endpoint_name
}

output "created_service_principal_id" {
  description = "Application ID of the created Service Principal"
  value       = azuread_application.vault_sp_app.client_id
}

output "created_service_principal_object_id" {
  description = "Object ID of the created Service Principal"
  value       = azuread_service_principal.vault_sp.object_id
}

# Note: No client secret - using passwordless Workload Identity Federation

output "service_principal_details" {
  description = "Service Principal details for Workload Identity Federation"
  sensitive   = true
  value = {
    client_id    = azuread_application.vault_sp_app.client_id
    object_id    = azuread_service_principal.vault_sp.object_id
    display_name = azuread_application.vault_sp_app.display_name
    tenant_id    = var.azure_tenant_id
    auth_method  = "Workload Identity Federation (passwordless)"
  }
}

output "setup_summary" {
  description = "Summary of created resources and next steps"
  value = <<-EOT
=== Azure DevOps + Vault Integration Setup Complete (Passwordless) ===

Created Resources:
• Project: ${azuredevops_project.vault_integration.name} (${azuredevops_project.vault_integration.id})
• Repository: ${azuredevops_git_repository.vault_integration_repo.name}
• Pipeline: ${azuredevops_build_definition.vault_integration_pipeline.name}
• Service Connection: ${azuredevops_serviceendpoint_azurerm.automatic.service_endpoint_name}
• Service Principal: ${azuread_application.vault_sp_app.display_name} (passwordless)

Project URL: ${var.azuredevops_org_service_url}/${azuredevops_project.vault_integration.name}
Repository URL: ${azuredevops_git_repository.vault_integration_repo.remote_url}

Security Features:
✅ Workload Identity Federation (no secrets stored)
✅ Federated identity credentials configured
✅ Service Principal with Owner permissions
✅ Complete passwordless authentication chain

Next Steps:
1. Create an azure-pipelines.yml file in your repository
2. Configure Vault environment variables (VAULT_ADDR)
3. Test the pipeline with Vault authentication

Note: This setup uses NO SECRETS - all authentication is federated and passwordless!
EOT
}