#!/usr/bin/env python3
"""
Test script to validate the Azure DevOps setup
"""

def test_imports():
    """Test if all required modules can be imported"""
    print("Testing imports...")
    
    try:
        from azure.devops.connection import Connection
        from azure.devops.v7_1.build import BuildClient
        from azure.devops.v7_1.build.models import Build
        from azure.identity import ClientSecretCredential
        from msrest.authentication import BasicAuthentication
        from dotenv import load_dotenv
        print("✅ All imports successful!")
        return True
    except ImportError as e:
        print(f"❌ Import error: {e}")
        return False

def test_environment():
    """Test environment variables"""
    print("Testing environment variables...")
    
    from dotenv import load_dotenv
    import os
    
    load_dotenv('azure_env.txt')
    
    required_vars = ['AZURE_TENANT_ID', 'AZURE_CLIENT_ID', 'AZURE_SUBSCRIPTION_ID']
    all_present = True
    
    for var in required_vars:
        value = os.getenv(var)
        if value:
            print(f"✅ {var}: {value[:8]}...")
        else:
            print(f"❌ {var}: Not found")
            all_present = False
    
    return all_present

def test_pipeline_yaml():
    """Test if pipeline YAML exists and is valid"""
    print("Testing pipeline YAML...")
    
    import os
    import yaml
    
    pipeline_file = 'azure-pipeline.yml'
    
    if not os.path.exists(pipeline_file):
        print(f"❌ {pipeline_file} not found")
        return False
    
    try:
        with open(pipeline_file, 'r') as f:
            pipeline_content = yaml.safe_load(f)
        
        # Check basic structure
        if 'jobs' in pipeline_content and len(pipeline_content['jobs']) > 0:
            job = pipeline_content['jobs'][0]
            if 'steps' in job and len(job['steps']) > 0:
                step = job['steps'][0]
                if 'script' in step and 'Hello World' in step['script']:
                    print("✅ Pipeline YAML is valid and contains Hello World step")
                    return True
        
        print("❌ Pipeline YAML structure is invalid")
        return False
        
    except Exception as e:
        print(f"❌ Error parsing pipeline YAML: {e}")
        return False

def main():
    print("Azure DevOps Setup Validation")
    print("=" * 30)
    
    tests = [
        ("Module Imports", test_imports),
        ("Environment Variables", test_environment),
        ("Pipeline YAML", test_pipeline_yaml)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🧪 {test_name}")
        if test_func():
            passed += 1
        print()
    
    print("=" * 30)
    print(f"Tests passed: {passed}/{total}")
    
    if passed == total:
        print("🎉 All tests passed! Setup is ready.")
        print("\nNext steps:")
        print("1. Create an Azure DevOps project")
        print("2. Create a pipeline using azure-pipeline.yml")
        print("3. Get a Personal Access Token")
        print("4. Update trigger_pipeline_pat.py with your details")
        print("5. Run: source venv/bin/activate && python trigger_pipeline_pat.py")
    else:
        print("❌ Some tests failed. Please check the setup.")

if __name__ == "__main__":
    main()