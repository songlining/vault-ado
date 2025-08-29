# Azure DevOps + HashiCorp Vault Integration (Passwordless)

This Terraform configuration creates a complete passwordless integration between Azure DevOps pipelines and HashiCorp Vault using Workload Identity Federation.

## 🔐 Security Features

- ✅ **Passwordless Authentication** - No secrets stored anywhere
- ✅ **Workload Identity Federation** - Uses Azure AD federated credentials
- ✅ **Environment Variable Configuration** - Keeps sensitive data out of code
- ✅ **Service Principal with Owner Permissions** - Full Azure access
- ✅ **Complete Azure DevOps Project Setup** - Project, repository, pipeline, and service connection

## 🚀 Quick Start

### 1. Set Environment Variables (Recommended)

```bash
# Azure Configuration
export ARM_TENANT_ID=$(az account show --query tenantId -o tsv)
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Azure DevOps Configuration  
export ADO_PAT="your-azure-devops-pat-token"

# HashiCorp Vault Configuration
export VAULT_ADDR="https://your-vault-server.com:8200"
export VAULT_TOKEN="your-vault-admin-token"
```

### 2. Configure Organization URL

```bash
# Copy and edit the terraform.tfvars file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars and set:
azuredevops_org_service_url = "https://dev.azure.com/your-organization"
```

### 3. Deploy Infrastructure

```bash
terraform init
terraform apply
```

## 📋 What Gets Created

### Azure Resources
- **Azure AD Application** - For Service Principal identity
- **Service Principal** - With Owner role on subscription  
- **Federated Identity Credential** - For passwordless authentication

### Azure DevOps Resources
- **Project** - With randomized name (e.g., `vault-integration-a1b2c3d4`)
- **Git Repository** - Ready for your code
- **Build Pipeline** - Configured to use `azure-pipelines.yml`
- **Service Connection** - Using Workload Identity Federation

## 🔧 Configuration Options

### Environment Variables (Recommended)

| Variable | Description | Required |
|----------|-------------|----------|
| `ARM_TENANT_ID` | Azure tenant ID | ✅ |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID | ✅ |
| `ADO_PAT` | Azure DevOps Personal Access Token | ✅ |
| `VAULT_ADDR` | HashiCorp Vault server URL | For Vault integration |
| `VAULT_TOKEN` | Vault admin token | For Vault integration |

### Terraform Variables

If you prefer not to use environment variables, you can set these in `terraform.tfvars`:

```hcl
# Azure Configuration
azure_tenant_id       = "your-tenant-id"
azure_subscription_id = "your-subscription-id"

# Azure DevOps Configuration
azuredevops_org_service_url       = "https://dev.azure.com/your-org"
azuredevops_personal_access_token = "your-pat-token"

# Project Configuration
azuredevops_project_name = "vault-integration"
project_visibility       = "private"
service_endpoint_name    = "AzureRM Service Connection for Vault with Automatic WIF"
```

## 🔐 Creating Personal Access Token

1. Go to Azure DevOps → User Settings → Personal Access Tokens
2. Click "New Token"
3. Set required scopes:
   - **Project and Team (Read & Write)** - To create projects
   - **Service Connections (Read & Write)** - To create service connections
   - **Build (Read & Write)** - To create pipelines
4. Copy the token and set it as `ADO_PAT` environment variable

## 🛠️ Usage in Azure DevOps Pipelines

After deployment, use the created service connection in your pipelines:

```yaml
# azure-pipelines.yml
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  VAULT_ADDR: 'https://your-vault-server.com:8200'

steps:
- task: AzureCLI@2
  displayName: 'Authenticate with Vault using Workload Identity'
  inputs:
    azureSubscription: 'AzureRM Service Connection for Vault with Automatic WIF'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      # Get JWT token from Azure (passwordless)
      JWT_TOKEN=$(az account get-access-token --resource https://management.core.windows.net/ --query accessToken -o tsv)
      
      # Authenticate with Vault using the JWT
      VAULT_TOKEN=$(curl -s -X POST \
        -d "{\"role\":\"ado-pipeline-role\",\"jwt\":\"$JWT_TOKEN\"}" \
        $VAULT_ADDR/v1/auth/ado/login | jq -r .auth.client_token)
      
      # Export for subsequent steps
      echo "##vso[task.setvariable variable=VAULT_TOKEN;issecret=true]$VAULT_TOKEN"

- script: |
    # Use Vault token to retrieve secrets
    SECRET=$(curl -s -H "X-Vault-Token: $(VAULT_TOKEN)" \
      $VAULT_ADDR/v1/secret/data/azure-devops/my-secret | jq -r .data.data.value)
    echo "Successfully retrieved secret from Vault"
  displayName: 'Retrieve secrets from Vault'
```

## 🧹 Cleanup

To remove all created resources:

```bash
terraform destroy
```

This will automatically:
- Delete the Azure AD application and service principal
- Remove all role assignments
- Delete the Azure DevOps project, repository, pipeline, and service connection

## 📝 Outputs

After successful deployment, Terraform provides:

- **Service Principal Details** - Client ID, Object ID, Display Name
- **Azure DevOps URLs** - Project and repository URLs
- **Service Connection Name** - For use in pipelines
- **Setup Summary** - Complete overview with next steps

## 🚨 Troubleshooting

### Permission Issues

If you get "Insufficient privileges" errors:

1. **For Azure AD operations** - Need "Application Administrator" role or equivalent
2. **For Azure subscription** - Need "Owner" or "Contributor" role
3. **For Azure DevOps** - Need "Project Administrator" permissions

### Authentication Failures

1. **Check environment variables** are set correctly
2. **Verify PAT token** has required scopes and isn't expired
3. **Confirm Azure CLI** is authenticated: `az account show`

### Service Connection Issues

1. **Wait for propagation** - Azure AD changes can take 5-10 minutes
2. **Check federated credential** configuration in Azure portal
3. **Verify issuer URL** matches your Azure DevOps organization

## 🔒 Security Best Practices

1. **Use Environment Variables** - Keep secrets out of code
2. **Rotate PAT Tokens** - Set shorter expiration periods
3. **Limit PAT Scopes** - Only grant required permissions
4. **Monitor Service Principals** - Regularly audit permissions
5. **Use Vault Policies** - Restrict secret access paths

## 📚 Additional Resources

- [Azure Workload Identity Federation](https://docs.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation)
- [HashiCorp Vault Azure Auth Method](https://www.vaultproject.io/docs/auth/azure)
- [Azure DevOps Service Connections](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints)