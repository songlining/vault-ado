#!/usr/bin/env python3
"""
Azure DevOps Pipeline Creation Script
Creates a new pipeline in Azure DevOps using PAT authentication
"""

from azure.devops.connection import Connection
from azure.devops.v7_1.build import BuildClient
from azure.devops.v7_1.build.models import BuildDefinition, BuildRepository
from msrest.authentication import BasicAuthentication
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv('azure_env.txt')

# Configuration
org = os.getenv("ADO_ORG")
ORGANIZATION_URL = f"https://dev.azure.com/{org}"
PROJECT_NAME = os.getenv("ADO_PROJECT")
PAT_TOKEN = os.getenv("ADO_PAT")

def get_azure_devops_connection():
    """Create connection to Azure DevOps using PAT"""
    credentials = BasicAuthentication('', PAT_TOKEN)
    
    connection = Connection(
        base_url=ORGANIZATION_URL,
        creds=credentials
    )
    
    return connection

def create_pipeline(name, repo_url, yaml_path="azure-pipelines.yml", default_branch="main"):
    """Create a new pipeline in Azure DevOps"""
    try:
        # Get connection
        connection = get_azure_devops_connection()
        
        # Get build client
        build_client = connection.clients.get_build_client()
        
        # Create repository object
        repository = BuildRepository(
            url=repo_url,
            default_branch=f"refs/heads/{default_branch}",
            type="TfsGit"  # Use "GitHub" for GitHub repos
        )
        
        # Create build definition with YAML process
        build_definition = BuildDefinition(
            name=name,
            repository=repository,
            process={
                "yamlFilename": yaml_path,
                "type": 2  # YAML process type
            },
            path="\\",  # Root folder
            type="build"
        )
        
        # Create the pipeline
        print(f"Creating pipeline '{name}'...")
        created_pipeline = build_client.create_definition(build_definition, PROJECT_NAME)
        
        print(f"Pipeline created successfully!")
        print(f"Pipeline ID: {created_pipeline.id}")
        print(f"Pipeline Name: {created_pipeline.name}")
        print(f"Pipeline URL: {created_pipeline._links.additional_properties['web']['href']}")
        
        return created_pipeline
        
    except Exception as e:
        print(f"Error creating pipeline: {e}")
        return None

if __name__ == "__main__":
    print("Azure DevOps Pipeline Creator")
    print("=" * 30)
    
    # Get user input for pipeline details
    pipeline_name = input("Enter pipeline name: ")
    repo_url = input("Enter repository URL: ")
    yaml_path = input("Enter YAML file path (default: azure-pipelines.yml): ") or "azure-pipelines.yml"
    branch = input("Enter default branch (default: main): ") or "main"
    
    create_pipeline(pipeline_name, repo_url, yaml_path, branch)