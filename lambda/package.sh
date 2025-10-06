#!/bin/bash
# Package Lambda functions for deployment

echo "Packaging Lambda functions..."

# Package start_investigation Lambda
cd /tmp
mkdir -p start_investigation_package
cp start_investigation.py start_investigation_package/index.py
cd start_investigation_package
zip -r ../lambda_start_investigation.zip .
cd ..
rm -rf start_investigation_package

# Package create_github_issue Lambda
mkdir -p github_issue_package
cp create_github_issue.py github_issue_package/index.py
cd github_issue_package
pip install requests -t .
zip -r ../lambda_github_issue.zip .
cd ..
rm -rf github_issue_package

echo "Lambda packages created:"
echo "  - lambda_start_investigation.zip"
echo "  - lambda_github_issue.zip"
