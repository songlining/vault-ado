# Generate random suffix for project name
resource "random_string" "project_suffix" {
  length  = 6
  upper   = false
  special = false
}

# Create Azure DevOps Project
resource "azuredevops_project" "vault_integration" {
  name         = "${var.azuredevops_project_name}-${random_string.project_suffix.result}"
  description  = "Project for HashiCorp Vault integration with Azure DevOps pipelines"
  visibility   = var.project_visibility
  
  version_control     = "Git"
  work_item_template  = "Agile"
  
  features = {
    "boards"       = "enabled"
    "repositories" = "enabled"
    "pipelines"    = "enabled"
    "testplans"    = "disabled"
    "artifacts"    = "enabled"
  }
}

# Create a Git repository in the project
resource "azuredevops_git_repository" "vault_integration_repo" {
  project_id = azuredevops_project.vault_integration.id
  name       = "${var.azuredevops_project_name}-repo"
  
  initialization {
    init_type = "Clean"
  }
}

# Create build definition (pipeline)
resource "azuredevops_build_definition" "vault_integration_pipeline" {
  project_id = azuredevops_project.vault_integration.id
  name       = "${var.azuredevops_project_name}-pipeline"
  path       = "\\"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.vault_integration_repo.id
    branch_name = azuredevops_git_repository.vault_integration_repo.default_branch
    yml_path    = "jwt-debug-pipeline.yml"
  }
}

# Create azure-pipelines.yml file in the repository
resource "azuredevops_git_repository_file" "azure_pipelines_yml" {
  repository_id = azuredevops_git_repository.vault_integration_repo.id
  file          = "jwt-debug-pipeline.yml"
  content = templatefile("${path.module}/templates/jwt-debug-pipeline.yml", {
    service_connection_name = var.service_endpoint_name
    vault_role_name         = "ado-pipeline-role"
    vault_auth_path         = "ado"
  })
  branch              = azuredevops_git_repository.vault_integration_repo.default_branch
  commit_message      = "Add Azure DevOps pipeline with Vault integration"
  overwrite_on_create = true
  
  depends_on = [
    azuredevops_git_repository.vault_integration_repo,
    azuredevops_build_definition.vault_integration_pipeline
  ]
}

# Create Environment for deployments
resource "azuredevops_environment" "vault_integration_env" {
  project_id  = azuredevops_project.vault_integration.id
  name        = "development"
  description = "Development environment for Vault integration testing"
}

# Grant pipeline permission to use the environment
resource "azuredevops_pipeline_authorization" "vault_pipeline_env_auth" {
  project_id  = azuredevops_project.vault_integration.id
  resource_id = azuredevops_environment.vault_integration_env.id
  type        = "environment"
  pipeline_id = azuredevops_build_definition.vault_integration_pipeline.id
}

# Grant pipeline permission to use the service connection
resource "azuredevops_pipeline_authorization" "vault_pipeline_serviceconnection_auth" {
  project_id  = azuredevops_project.vault_integration.id
  resource_id = azuredevops_serviceendpoint_azurerm.automatic.id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.vault_integration_pipeline.id
}

# Get the Default agent queue for this project
data "azuredevops_agent_queue" "default" {
  project_id = azuredevops_project.vault_integration.id
  name       = "Default"
}

# Grant pipeline permission to use the Default agent queue
resource "azuredevops_pipeline_authorization" "vault_pipeline_agentqueue_auth" {
  project_id  = azuredevops_project.vault_integration.id
  resource_id = data.azuredevops_agent_queue.default.id
  type        = "queue"
  pipeline_id = azuredevops_build_definition.vault_integration_pipeline.id
}