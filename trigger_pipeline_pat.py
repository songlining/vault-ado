#!/usr/bin/env python3
"""
Azure DevOps Pipeline Trigger Script (PAT Authentication)
Simpler version using Personal Access Token
"""

import time
from azure.devops.connection import Connection
from azure.devops.v7_1.build import BuildClient
from azure.devops.v7_1.build.models import Build
from msrest.authentication import BasicAuthentication
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv('azure_env.txt')

# Configuration - you'll need to update these values
org = os.getenv("ADO_ORG")  # Read from azure_env.txt
ORGANIZATION_URL = f"https://dev.azure.com/{org}"  # Update this
PROJECT_NAME = os.getenv("ADO_PROJECT")  # Read from azure_env.txt
PIPELINE_ID = 1  # Update this to your pipeline ID
PAT_TOKEN = os.getenv("ADO_PAT") 

def get_azure_devops_connection():
    """Create connection to Azure DevOps using PAT"""
    # Create credential using PAT
    credentials = BasicAuthentication('', PAT_TOKEN)
    
    # Create connection
    connection = Connection(
        base_url=ORGANIZATION_URL,
        creds=credentials
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
    print(f"\\nMonitoring build {build_id}...")
    
    while True:
        build = build_client.get_build(PROJECT_NAME, build_id)
        
        print(f"Build status: {build.status}")
        
        if build.status == 'completed':
            print(f"Build result: {build.result}")
            
            # Get build logs to show "Hello World" output
            try:
                logs = build_client.get_build_logs(PROJECT_NAME, build_id)
                print("\\n=== Build Logs ===")
                for log in logs:
                    log_content = build_client.get_build_log(PROJECT_NAME, build_id, log.id)
                    if "Hello World" in log_content or "Print Hello World" in log_content:
                        print(f"--- Log {log.id} ({log.type}) ---")
                        print(log_content)
                        print("--- End Log ---")
                print("=== End Build Logs ===")
            except Exception as e:
                print(f"Could not retrieve logs: {e}")
            
            break
        
        time.sleep(5)

if __name__ == "__main__":
    print("Azure DevOps Pipeline Trigger (PAT)")
    print("=" * 35)
    
    # Check if configuration is set
    if ORGANIZATION_URL == "https://dev.azure.com/YOUR_ORGANIZATION":
        print("⚠️  Please update the configuration variables:")
        print("   - ORGANIZATION_URL")
        print("   - PROJECT_NAME") 
        print("   - PIPELINE_ID")
        print("   - PAT_TOKEN")
        exit(1)
    
    trigger_pipeline()