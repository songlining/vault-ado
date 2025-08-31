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

# Enable JWT auth method for Azure DevOps (more compatible with Azure DevOps WIF)
resource "vault_auth_backend" "ado" {
  type = "jwt"
  path = "ado"
  description = "JWT auth backend for Azure DevOps integration"
}

# Configure JWT auth method for Azure AD tokens
resource "vault_jwt_auth_backend" "ado" {
  path            = vault_auth_backend.ado.path
  oidc_discovery_url = "https://login.microsoftonline.com/${var.azure_tenant_id}/v2.0"
  bound_issuer    = "https://sts.windows.net/${var.azure_tenant_id}/"
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
resource "vault_jwt_auth_backend_role" "ado_pipeline_role" {
  backend         = vault_auth_backend.ado.path
  role_name       = "ado-pipeline-role"
  token_policies  = [vault_policy.ado_pipeline_policy.name]
  
  # Bind to specific Azure AD application (service principal)
  bound_audiences = ["https://management.core.windows.net/"]
  bound_subject   = azuread_service_principal.vault_sp.object_id
  bound_claims = {
    iss = "https://sts.windows.net/${var.azure_tenant_id}/"
    tid = var.azure_tenant_id
  }
  
  user_claim      = "oid"
  role_type       = "jwt"
  token_ttl       = 3600
  token_max_ttl   = 7200
}