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
    yml_path    = "azure-pipelines.yml"
  }
}

# Create azure-pipelines.yml file in the repository
resource "azuredevops_git_repository_file" "azure_pipelines_yml" {
  repository_id = azuredevops_git_repository.vault_integration_repo.id
  file          = "azure-pipelines.yml"
  content = templatefile("${path.module}/templates/azure-pipelines.yml", {
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