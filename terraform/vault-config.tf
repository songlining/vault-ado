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

# Enable Azure auth method for Azure DevOps
resource "vault_auth_backend" "ado" {
  type = "azure"
  path = "ado"
  description = "Azure auth backend for Azure DevOps integration"
}

# Configure Azure auth method
resource "vault_azure_auth_backend_config" "ado" {
  backend       = vault_auth_backend.ado.path
  tenant_id     = var.azure_tenant_id
  resource      = "https://management.core.windows.net/"
  client_id     = azuread_application.vault_sp_app.client_id
  client_secret = azuread_application_password.vault_sp_password.value
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

# Create role for Azure DevOps pipeline authentication
resource "vault_azure_auth_backend_role" "ado_pipeline_role" {
  backend         = vault_auth_backend.ado.path
  role            = "ado-pipeline-role"
  token_policies  = [vault_policy.ado_pipeline_policy.name]
  
  # Allow authentication from Azure resources
  bound_subscription_ids = [var.azure_subscription_id]
  bound_resource_groups  = ["*"]  # Allow any resource group
  
  token_ttl     = 3600
  token_max_ttl = 7200
}