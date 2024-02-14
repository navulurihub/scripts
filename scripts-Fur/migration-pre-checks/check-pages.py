################ 
# SCRIPT USAGE #
################ 
# This script is used to print github pages audit report as a csv file
# For all the listed organisations in the script, it will fetch list of repos
# For each repo, script will check for pages enablement and writes into a csv file
################
# To execute the script in local follow the below instructions:
# 1. export GHES_HOSTNAME, GH_SOURCE_PAT(GHES token) to the local environment variables
# 2. Update the org_list if any changes needed to the list provided and target_org values
# 3. Run PyGithub by running `pip install PyGithub` (if required)
# 4. Run the script with command `python3 check-pages.py`
# 5. Once execution is complete, audit results will be written into 'github_pages_audit.csv' file
################

import os
import csv
from github import Github

# env variables settings

org_list = [
    "ictawspipeline",
    "ictazurepipeline",
    "Usyd-Integration",
    "ICT-Learning-Environment",
    "rc",
    "ictautomation",
    "AVSE",
    "ict-app-provisioning",
    "university-infrastructure",
    "ictTestAutomation",
    "EngITSalesforce",
    "HR-WORKDAY",
    "CyberSecurity",
    "cyberops"
]

hostname = os.getenv("GHES_HOSTNAME")
token_ghes = os.getenv("GH_SOURCE_PAT")

# REST API settings
ghes = Github(base_url=f'https://{hostname}/api/v3', login_or_token=token_ghes)

csv_file = "github_pages_audit.csv"

#Delete the csv file if exists
if os.path.exists(csv_file):
  os.remove(csv_file)

if token_ghes and hostname:
    for org_name in org_list:
        print("Cheking Github Pages feature for :", org_name ) 
        header = ['org_name', 'repo_name', 'has_pages?']
        org_obj = ghes.get_organization(org_name)
        repos = org_obj.get_repos()
        for repo in repos:
            repo_name = repo.name
            has_pages = repo.has_pages
            data_to_write = [org_name, repo_name, has_pages]
            with open(csv_file, mode='a') as pages_audit_file:
                pages_audit_writer = csv.writer(pages_audit_file, delimiter=',', quotechar='"',
                                                    quoting=csv.QUOTE_MINIMAL)
                if os.stat(csv_file).st_size == 0:
                    pages_audit_writer.writerow(header)
                pages_audit_writer.writerow(data_to_write)        
else:
    print('Please set your GH_SOURCE_PAT and GHES_HOSTNAME.')
