#!/usr/bin/env python3
"""
Azure DevOps Pipeline Trigger Script
Triggers a pipeline and monitors its execution
"""

import os
import time
from azure.devops.connection import Connection
from azure.devops.v7_1.build import BuildClient
from azure.devops.v7_1.build.models import Build
from azure.identity import ClientSecretCredential
from dotenv import load_dotenv

# Load environment variables
load_dotenv('azure_env.txt')

# Configuration - you'll need to update these values
ORGANIZATION_URL = "https://dev.azure.com/YOUR_ORGANIZATION"  # Update this
PROJECT_NAME = "YOUR_PROJECT"  # Update this
PIPELINE_ID = 1  # Update this to your pipeline ID

def get_azure_devops_connection():
    """Create connection to Azure DevOps using service principal"""
    tenant_id = os.getenv('AZURE_TENANT_ID')
    client_id = os.getenv('AZURE_CLIENT_ID')
    client_secret = os.getenv('AZURE_CLIENT_SECRET')  # You'll need to add this
    
    if not all([tenant_id, client_id, client_secret]):
        raise ValueError("Missing required environment variables")
    
    # Create credential
    credential = ClientSecretCredential(
        tenant_id=tenant_id,
        client_id=client_id,
        client_secret=client_secret
    )
    
    # Create connection
    connection = Connection(
        base_url=ORGANIZATION_URL,
        creds=credential
    )
    
    return connection

def trigger_pipeline():
    """Trigger the Azure DevOps pipeline"""
    try:
        # Get connection
        connection = get_azure_devops_connection()
        
        # Get build client
        build_client = connection.clients.get_build_client()
        
        # Create build request
        build = Build(
            definition={'id': PIPELINE_ID},
            source_branch='refs/heads/main'
        )
        
        # Queue the build
        print(f"Triggering pipeline {PIPELINE_ID}...")
        queued_build = build_client.queue_build(build, PROJECT_NAME)
        
        print(f"Pipeline queued successfully!")
        print(f"Build ID: {queued_build.id}")
        print(f"Build URL: {queued_build._links.additional_properties['web']['href']}")
        
        # Monitor the build
        monitor_build(build_client, queued_build.id)
        
    except Exception as e:
        print(f"Error triggering pipeline: {e}")

def monitor_build(build_client: BuildClient, build_id: int):
    """Monitor the build execution and show logs"""
    print(f"Monitoring build {build_id}...")
    
    while True:
        build = build_client.get_build(PROJECT_NAME, build_id)
        
        print(f"Build status: {build.status}")
        
        if build.status == 'completed':
            print(f"Build result: {build.result}")
            
            # Get build logs
            try:
                logs = build_client.get_build_logs(PROJECT_NAME, build_id)
                for log in logs:
                    log_content = build_client.get_build_log(PROJECT_NAME, build_id, log.id)
                    print(f"--- Log {log.id} ---")
                    print(log_content)
                    print("--- End Log ---")
            except Exception as e:
                print(f"Could not retrieve logs: {e}")
            
            break
        
        time.sleep(5)

if __name__ == "__main__":
    print("Azure DevOps Pipeline Trigger")
    print("=" * 30)
    trigger_pipeline()