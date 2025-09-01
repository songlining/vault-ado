# Vault Configuration Resources

# Enable KV v2 secrets engine
resource "vault_mount" "kv_v2" {
  path        = "secret"
  type        = "kv-v2"
  description = "KV v2 secrets engine for demo"
}

# Demo secret for testing
resource "vault_kv_secret_v2" "demo_secret" {
  mount                      = vault_mount.kv_v2.path
  name                       = "demo"
  cas                        = 1
  delete_all_versions        = true
  data_json                  = jsonencode({
    username = "demo-user"
    password = "demo-password"
    api_key  = "demo-api-key-12345"
  })
}

# Enable Azure auth method for Azure DevOps with proper configuration
resource "vault_auth_backend" "ado" {
  type = "azure"
  path = "ado"
  description = "Azure auth backend for Azure DevOps integration with subscription binding"
}

# Configure Azure auth method for service principal authentication
# This service principal needs read access to Azure Resource Manager
resource "vault_azure_auth_backend_config" "ado" {
  backend       = vault_auth_backend.ado.path
  tenant_id     = var.azure_tenant_id
  resource      = "https://management.core.windows.net/"
  client_id     = azuread_application.vault_sp_app.client_id
  client_secret = azuread_application_password.vault_sp_password.value
  
  # Environment should be AzurePublicCloud for standard Azure (default)
  environment = "AzurePublicCloud"
}

# Create policy for ADO pipeline
resource "vault_policy" "ado_pipeline_policy" {
  name = "ado-pipeline-policy"

  policy = <<EOT
# Allow reading secrets from the demo path
path "secret/data/demo" {
  capabilities = ["read"]
}

# Allow listing secrets
path "secret/metadata/*" {
  capabilities = ["list"]
}
EOT
}

# Create role for Azure DevOps pipeline authentication with proper service principal binding
resource "vault_azure_auth_backend_role" "ado_pipeline_role" {
  backend         = vault_auth_backend.ado.path
  role            = "ado-pipeline-role"
  token_policies  = [vault_policy.ado_pipeline_policy.name]

  # Bind to specific service principal object ID (matches JWT oid field)
  bound_service_principal_ids = [azuread_service_principal.vault_sp.object_id]
  
  # No subscription binding needed for Azure DevOps pipelines (per HashiCorp blog)
  bound_subscription_ids = []
  
  token_ttl     = 3600
  token_max_ttl = 7200
  token_type    = "batch"
}