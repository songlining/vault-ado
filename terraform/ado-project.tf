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
  name       = "vault-integration-repo"
  
  initialization {
    init_type = "Clean"
  }
}

# Create build definition (pipeline)
resource "azuredevops_build_definition" "vault_integration_pipeline" {
  project_id = azuredevops_project.vault_integration.id
  name       = "vault-integration-pipeline"
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