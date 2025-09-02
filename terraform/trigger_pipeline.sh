#!/bin/bash

# Azure DevOps Pipeline Trigger Script
# This script manually triggers the Vault integration pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "  Azure DevOps Pipeline Trigger"
    echo "  Vault Integration Demo"
    echo "=================================================="
    echo -e "${NC}"
}

# Check if terraform outputs are available
check_terraform_outputs() {
    print_info "Checking Terraform outputs..."
    
    if ! terraform output > /dev/null 2>&1; then
        print_error "Terraform outputs not available. Run 'terraform apply' first."
        exit 1
    fi
    
    print_success "Terraform outputs available"
}

# Get values from terraform outputs
get_terraform_values() {
    print_info "Getting configuration from Terraform outputs..."
    
    PROJECT_URL=$(terraform output -raw azuredevops_project_url 2>/dev/null || echo "")
    PROJECT_NAME=$(terraform output -raw azuredevops_project_name 2>/dev/null || echo "")
    PIPELINE_ID=$(terraform output -raw build_pipeline_id 2>/dev/null || echo "")
    PROJECT_ID=$(terraform output -raw azuredevops_project_id 2>/dev/null || echo "")
    
    # Extract organization URL from project URL
    # Format: https://dev.azure.com/songlining/project-name -> https://dev.azure.com/songlining
    if [[ -n "$PROJECT_URL" ]]; then
        ORG_URL=$(echo "$PROJECT_URL" | sed 's/\/[^/]*$//')
    fi
    
    if [[ -z "$ORG_URL" || -z "$PROJECT_NAME" || -z "$PIPELINE_ID" ]]; then
        print_error "Missing required Terraform outputs. Ensure infrastructure is deployed."
        print_info "Available outputs:"
        terraform output
        exit 1
    fi
    
    print_success "Retrieved configuration:"
    echo "  Organization: $ORG_URL"
    echo "  Project: $PROJECT_NAME"
    echo "  Pipeline ID: $PIPELINE_ID"
    echo
}

# Check if Azure DevOps CLI extension is installed
check_az_devops_extension() {
    print_info "Checking Azure DevOps CLI extension..."
    
    if ! az extension show --name azure-devops >/dev/null 2>&1; then
        print_warning "Azure DevOps CLI extension not installed. Installing..."
        az extension add --name azure-devops
        print_success "Azure DevOps CLI extension installed"
    else
        print_success "Azure DevOps CLI extension already installed"
    fi
}

# Configure Azure DevOps CLI
configure_az_devops() {
    print_info "Configuring Azure DevOps CLI..."
    
    # Set default organization
    az devops configure --defaults organization="$ORG_URL" project="$PROJECT_NAME"
    
    print_success "Azure DevOps CLI configured"
}

# Parse command line parameters
parse_parameters() {
    PIPELINE_PARAMS=""
    
    # Parse command line arguments for custom parameters
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                if [[ -n "$PIPELINE_PARAMS" ]]; then
                    PIPELINE_PARAMS="$PIPELINE_PARAMS env=$2"
                else
                    PIPELINE_PARAMS="env=$2"
                fi
                shift 2
                ;;
            --size)
                if [[ -n "$PIPELINE_PARAMS" ]]; then
                    PIPELINE_PARAMS="$PIPELINE_PARAMS size=$2"
                else
                    PIPELINE_PARAMS="size=$2"
                fi
                shift 2
                ;;
            --param)
                if [[ -n "$PIPELINE_PARAMS" ]]; then
                    PIPELINE_PARAMS="$PIPELINE_PARAMS $2"
                else
                    PIPELINE_PARAMS="$2"
                fi
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -n "$PIPELINE_PARAMS" ]]; then
        print_info "Pipeline parameters: $PIPELINE_PARAMS"
    fi
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --env VALUE        Set environment parameter (e.g., --env production)"
    echo "  --size VALUE       Set size parameter (e.g., --size small)"
    echo "  --param KEY=VALUE  Set custom parameter (e.g., --param region=us-east-1)"
    echo "  -h, --help         Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --env production --size small"
    echo "  $0 --param env=production --param size=small"
    echo "  $0 --env dev --param region=us-west-2 --param debug=true"
}

# Trigger the pipeline
trigger_pipeline() {
    print_info "Triggering pipeline..."
    
    # Build the az pipelines run command with parameters
    AZ_COMMAND="az pipelines run --id '$PIPELINE_ID' --output json"
    
    if [[ -n "$PIPELINE_PARAMS" ]]; then
        # Convert space-separated params to comma-separated format for Azure DevOps
        FORMATTED_PARAMS=$(echo "$PIPELINE_PARAMS" | sed 's/ /,/g')
        AZ_COMMAND="$AZ_COMMAND --parameters $FORMATTED_PARAMS"
        
        print_info "Running: az pipelines run --id $PIPELINE_ID --parameters $FORMATTED_PARAMS"
    fi
    
    # Execute the command
    RUN_OUTPUT=$(eval "$AZ_COMMAND" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        RUN_ID=$(echo "$RUN_OUTPUT" | jq -r '.id // empty')
        RUN_URL=$(echo "$RUN_OUTPUT" | jq -r '.url // empty')
        
        print_success "Pipeline triggered successfully!"
        echo "  Run ID: $RUN_ID"
        echo "  Pipeline URL: ${ORG_URL}/${PROJECT_NAME}/_build/results?buildId=${RUN_ID}"
        
        if [[ -n "$PIPELINE_PARAMS" ]]; then
            echo "  Parameters: $PIPELINE_PARAMS"
        fi
        echo
        
        return 0
    else
        print_error "Failed to trigger pipeline"
        print_info "Command attempted: $AZ_COMMAND"
        print_info "Error output: $RUN_OUTPUT"
        return 1
    fi
}

# Monitor pipeline status (optional)
monitor_pipeline() {
    if [[ -n "$RUN_ID" ]]; then
        print_info "Monitoring pipeline status..."
        
        while true; do
            STATUS=$(az pipelines runs show --id "$RUN_ID" --query "status" -o tsv 2>/dev/null)
            RESULT=$(az pipelines runs show --id "$RUN_ID" --query "result" -o tsv 2>/dev/null)
            
            case "$STATUS" in
                "completed")
                    case "$RESULT" in
                        "succeeded")
                            print_success "Pipeline completed successfully!"
                            break
                            ;;
                        "failed")
                            print_error "Pipeline failed!"
                            break
                            ;;
                        "canceled")
                            print_warning "Pipeline was canceled"
                            break
                            ;;
                        *)
                            print_warning "Pipeline completed with result: $RESULT"
                            break
                            ;;
                    esac
                    ;;
                "inProgress"|"running")
                    print_info "Pipeline is running... (Status: $STATUS)"
                    sleep 10
                    ;;
                *)
                    print_info "Pipeline status: $STATUS"
                    sleep 5
                    ;;
            esac
        done
    fi
}

# Show pipeline logs (optional)
show_logs() {
    if [[ -n "$RUN_ID" ]]; then
        read -p "Do you want to view the pipeline logs? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Fetching pipeline logs..."
            az pipelines runs show-log --id "$RUN_ID" --output table
        fi
    fi
}

# Main execution
main() {
    # Parse parameters first
    parse_parameters "$@"
    
    print_header
    
    # Check prerequisites
    check_terraform_outputs
    get_terraform_values
    check_az_devops_extension
    
    # Configure and trigger
    configure_az_devops
    
    if trigger_pipeline; then
        # Ask if user wants to monitor
        read -p "Do you want to monitor the pipeline execution? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            monitor_pipeline
            show_logs
        else
            print_info "Pipeline triggered. You can monitor it at:"
            echo "  ${ORG_URL}/${PROJECT_NAME}/_build/results?buildId=${RUN_ID}"
        fi
        
        print_success "Done!"
    else
        print_error "Failed to trigger pipeline"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi