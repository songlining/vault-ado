# Azure DevOps + HashiCorp Vault Integration (Passwordless)

This Terraform configuration creates a complete passwordless integration between Azure DevOps pipelines and HashiCorp Vault using Workload Identity Federation and Azure auth backend.

## 🏗️ Architecture Overview

```
Azure DevOps Pipeline → Azure AD (WIF) → JWT Token → Vault (Azure Auth) → Secrets
```

**Authentication Flow:**
1. Azure DevOps pipeline runs with service connection (WIF)
2. Azure CLI generates JWT token with service principal's object ID
3. JWT token sent to Vault's Azure auth backend
4. Vault validates JWT and returns Vault token
5. Pipeline uses Vault token to access secrets

## 🔐 Security Features

- ✅ **Passwordless Authentication** - No secrets stored anywhere
- ✅ **Workload Identity Federation** - Uses Azure AD federated credentials  
- ✅ **Service Principal Binding** - Vault role bound to specific object ID
- ✅ **No Subscription Constraints** - Follows HashiCorp guidance for pipelines
- ✅ **Complete Azure DevOps Project Setup** - Project, repository, pipeline, and service connection

## 🚀 Quick Start

### 1. Prerequisites

- Azure CLI authenticated (`az login --tenant your-tenant-name`)
- Terraform installed
- HashiCorp Vault server running and accessible
- Azure DevOps organization with admin access
- Agent VM to run agent pool

### 2. Set Environment Variables (Recommended)

```bash
# Azure Configuration (auto-detect current context)
export TF_VAR_azure_tenant_id=$(az account show --query tenantId -o tsv)
export TF_VAR_azure_subscription_id=$(az account show --query id -o tsv)

# Azure DevOps Configuration  
export TF_VAR_azuredevops_org_service_url="https://dev.azure.com/your-organization"
export TF_VAR_azuredevops_personal_access_token="your-azure-devops-pat-token"

# HashiCorp Vault Configuration
export VAULT_ADDR="https://your-vault-server.com:8200"
export VAULT_TOKEN="your-vault-admin-token"
export VAULT_SKIP_VERIFY="1"  # If using self-signed certificates
export TF_VAR_vault_addr="$VAULT_ADDR"
```

### 3. Deploy Infrastructure

```bash
terraform init
terraform apply
```

## 📋 What Gets Created

### Azure Resources
- **Azure AD Application** - Service Principal identity
- **Service Principal** - With Owner role on subscription  
- **Federated Identity Credential** - Links to Azure DevOps service connection
- **Role Assignment** - Owner permissions on subscription

### Azure DevOps Resources  
- **Project** - With randomized name (e.g., `vault-wif-a1b2c3`)
- **Git Repository** - Ready for pipeline code
- **Build Pipeline** - Configured to use `simple-vault-pipeline.yml`
- **Service Connection** - Using Workload Identity Federation (passwordless)
- **Environment** - Development environment for deployments
- **Pipeline Authorizations** - Permissions for service connection, agent queue, environment

### HashiCorp Vault Resources
- **KV v2 Secrets Engine** - Mounted at `secret/`
- **Demo Secret** - `secret/demo` with test credentials
- **Azure Auth Backend** - Mounted at `auth/ado`
- **Azure Auth Configuration** - Service principal credentials for validation
- **Pipeline Policy** - Read access to `secret/data/demo`
- **Pipeline Role** - `ado-pipeline-role` bound to service principal object ID

## 🔧 Key Configuration Details

### Vault Role Configuration

The Vault Azure auth role is configured with:

```hcl
resource "vault_azure_auth_backend_role" "ado_pipeline_role" {
  backend         = vault_auth_backend.ado.path
  role            = "ado-pipeline-role"
  token_policies  = ["ado-pipeline-policy"]
  
  # Critical: Use object_id, not client_id (matches JWT oid field)
  bound_service_principal_ids = [azuread_service_principal.vault_sp.object_id]
  
  # No subscription binding needed for Azure DevOps pipelines
  bound_subscription_ids = []
  
  token_ttl     = 3600
  token_max_ttl = 7200
  token_type    = "batch"
}
```

**Important**: The `bound_service_principal_ids` must use the service principal's **object ID**, not client ID, as it matches the `oid` field in the JWT token.

### Pipeline Authentication

The pipeline uses Vault CLI for authentication:

```bash
# Get JWT token from Azure CLI
JWT=$(az account get-access-token --resource https://management.core.windows.net/ --query accessToken --output tsv)

# Authenticate with Vault (no subscription_id needed)
vault write -format=json auth/ado/login role="ado-pipeline-role" jwt="$JWT"
```

## 📝 Environment Variables & Variables

### Environment Variables (Recommended)

| Variable | Description | Required |
|----------|-------------|----------|
| `TF_VAR_azure_tenant_id` | Azure tenant ID | ✅ |
| `TF_VAR_azure_subscription_id` | Azure subscription ID | ✅ |
| `TF_VAR_azuredevops_org_service_url` | Azure DevOps organization URL | ✅ |
| `TF_VAR_azuredevops_personal_access_token` | Azure DevOps PAT | ✅ |
| `VAULT_ADDR` | HashiCorp Vault server URL | For Vault resources |
| `VAULT_TOKEN` | Vault admin token | For Vault resources |
| `VAULT_SKIP_VERIFY` | Skip TLS verification | For self-signed certs |
| `TF_VAR_vault_addr` | Vault address for pipeline | Optional |

### Terraform Variables

Alternatively, set these in `terraform.tfvars`:

```hcl
# Azure Configuration
azure_tenant_id       = "your-tenant-id"
azure_subscription_id = "your-subscription-id"

# Azure DevOps Configuration
azuredevops_org_service_url       = "https://dev.azure.com/your-org"
azuredevops_personal_access_token = "your-pat-token"

# Project Configuration
azuredevops_project_name = "vault-wif"
project_visibility       = "private"
service_endpoint_name    = "AzureRM Service Connection for Vault with Automatic WIF v2"

# Vault Configuration
vault_addr = "https://your-vault-server.com:8200"
```

## 🔐 Creating Personal Access Token

1. Go to Azure DevOps → User Settings → Personal Access Tokens
2. Click "New Token"
3. Set required scopes:
   - **Project and Team (Read & Write)** - To create projects
   - **Service Connections (Read & Write)** - To create service connections
   - **Build (Read & Write)** - To create pipelines
   - **Environment (Read & Write)** - To create environments
4. Copy the token and set it as environment variable

## 📚 Pipeline Templates

The repository includes several pipeline templates:

### 1. `simple-vault-pipeline.yml` (Primary)
- Complete Vault authentication workflow
- JWT token acquisition and validation
- Secret retrieval with error handling
- Token cleanup and security best practices
- **Used by default** in the created build pipeline

### 2. `jwt-debug-pipeline.yml`
- Decodes and displays JWT token contents
- Useful for troubleshooting authentication issues
- Shows token metadata and structure

### 3. `azure-pipelines.yml`
- Advanced pipeline with multiple authentication methods
- Comprehensive error handling and fallback logic
- Environment-specific configurations

### 4. `vault-auth-pipeline.yml`
- Focused on Vault authentication patterns
- Different auth backend examples
- Token management best practices

## 🛠️ Usage Example

After deployment, the pipeline automatically uses the working configuration:

```yaml
# The created simple-vault-pipeline.yml includes:
trigger:
- main

pool: Default

variables:
  VAULT_ADDR: 'https://your-vault-server.com:8200'
  VAULT_SKIP_VERIFY: '1'

jobs:
- job: VaultDemo
  displayName: 'Simple Vault Integration Demo'
  steps:
  - task: AzureCLI@2
    displayName: 'Get Secret from Vault'
    inputs:
      azureSubscription: 'AzureRM Service Connection for Vault with Automatic WIF v2'
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        # Get JWT token
        JWT=$(az account get-access-token --resource https://management.core.windows.net/ --query accessToken --output tsv)
        
        # Authenticate with Vault
        vault write -format=json auth/ado/login role="ado-pipeline-role" jwt="$JWT" > /tmp/vault_response.json
        VAULT_TOKEN=$(cat /tmp/vault_response.json | jq -r '.auth.client_token')
        
        # Read secret
        vault kv get secret/demo
        
        # Clean up
        vault token revoke -self
```

## 🧹 Cleanup

To remove all created resources:

```bash
terraform destroy
```

This automatically removes:
- Azure AD application and service principal
- All role assignments
- Azure DevOps project, repository, pipeline, and service connection
- Vault auth backend, policies, and roles

## Agent Pool

If you don't want to run Microsoft hosted agent pool, you can setup your own one by running either a VM on your laptop or somewhere in the cloud. 

Depending on what you will need in your pipeline, you may want to pre-install the tools on the VM. Currently I am running a Ubuntu 24 server on my Macbook with the `vault` package pre-installed so the pipeline will be able to run vault commands. I think this is better than having to install all the dependencies in the pipelines. 

You only need to setup the agent once as long as you keep using the same org, pool name and PAT.

## 🚨 Troubleshooting

### Authentication Failures

**Error: "service principal not authorized"**

**Solution**: Ensure Vault role uses service principal **object ID**, not client ID:

```bash
# Check current configuration
vault read auth/ado/role/ado-pipeline-role

# Should show: bound_service_principal_ids = [object-id-from-jwt]
# JWT oid field must match bound_service_principal_ids
```

**Error: "bound_subscription_ids" preventing authentication**

**Solution**: Remove subscription constraints (not needed for pipelines):

```bash
vault write auth/ado/role/ado-pipeline-role \
  bound_service_principal_ids="object-id" \
  bound_subscription_ids="" \
  policies="ado-pipeline-policy"
```

### Service Connection Issues

1. **Wait for propagation** - Azure AD changes take 5-10 minutes
2. **Check federated credential** in Azure Portal → App registrations
3. **Verify issuer URL** matches Azure DevOps organization

### Vault Connectivity Issues

1. **Set VAULT_SKIP_VERIFY=1** for self-signed certificates
2. **Check network connectivity** from pipeline agent to Vault
3. **Verify Vault auth backend** is mounted at `auth/ado`

### Permission Issues

**For Azure AD operations**: Need "Application Administrator" role
**For Azure subscription**: Need "Owner" or "Contributor" role  
**For Azure DevOps**: Need "Project Administrator" permissions

## 🔒 Security Best Practices

1. **Use Environment Variables** - Keep secrets out of code
2. **Rotate PAT Tokens** - Set shorter expiration periods
3. **Limit PAT Scopes** - Only grant required permissions
4. **Monitor Service Principals** - Regularly audit permissions
5. **Use Vault Policies** - Restrict secret access paths
6. **Token Cleanup** - Always revoke Vault tokens after use
7. **Network Security** - Restrict Vault access to pipeline agents

## 🌍 Multi-Environment Setup

For production deployments, consider:

### Option 1: Multiple Service Principals
```hcl
# Create environment-specific service principals
resource "azuread_service_principal" "vault_sp_prod" { ... }
resource "azuread_service_principal" "vault_sp_dev" { ... }

# Create environment-specific Vault roles
resource "vault_azure_auth_backend_role" "ado_pipeline_role_prod" {
  role = "ado-pipeline-role-prod"
  bound_service_principal_ids = [azuread_service_principal.vault_sp_prod.object_id]
  token_policies = ["prod-policy"]
}
```

### Option 2: Azure AD Group-Based
```hcl
# Create groups for environments
resource "azuread_group" "vault_prod_group" {
  display_name = "vault-prod-pipelines"
}

# Bind Vault roles to groups
resource "vault_azure_auth_backend_role" "ado_pipeline_role_prod" {
  role = "ado-pipeline-role-prod"
  bound_group_ids = [azuread_group.vault_prod_group.object_id]
  token_policies = ["prod-policy"]
}
```

## 📚 Additional Resources

- [HashiCorp Blog: Integrating Azure DevOps with Vault](https://www.hashicorp.com/en/blog/integrating-azure-devops-pipelines-with-hashicorp-vault)
- [Vault Azure Auth Method](https://developer.hashicorp.com/vault/docs/auth/azure)
- [Azure Workload Identity Federation](https://docs.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation)
- [Azure DevOps Service Connections](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints)
- [Vault Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)

## 📋 File Structure

```
terraform/
├── README.md                    # This file
├── main.tf                      # Provider configurations
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── azure-sp.tf                  # Azure AD resources
├── ado-project.tf               # Azure DevOps resources  
├── vault-config.tf              # Vault configuration
└── templates/
    ├── simple-vault-pipeline.yml    # Primary working template
    ├── jwt-debug-pipeline.yml       # JWT debugging
    ├── azure-pipelines.yml          # Advanced template
    └── vault-auth-pipeline.yml      # Auth-focused template
```