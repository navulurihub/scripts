################ 
# SCRIPT USAGE #
################ 
# This script is used to perform the following pre-migration checks
# For Source 
#     - Check token if it is active or invalid
#     - Check the access to the source organisation
#     - Check if the migration scope repos (listed) exists in source organisation
#     - Check for the each repo size and flag if size is > 2GB
# For Target
#     - Check token if it is active or invalid
#     - Check the access to the target organisation
#     - Check if the repositories already exist in target organisation
################
# To execute the script in local follow the below instructions:
# 1. export GHES_HOSTNAME, GH_SOURCE_PAT(GHES token) and GH_PAT (EMU token) to the local environment variables
# 2. Update the source_org and target_org values
# 3. Provide the list of repos in the repo_list (as shown below)
# 4. Run PyGithub by running `pip install PyGithub` (if required)
################

import os
import sys
from github import Github

# env variables settings

#repo_list  ="repo_list.txt" 
repo_list = [
    "addc-win2k19-devshared",
    "pamp-azure-win2019",
    "base-azure-win2019",
    "base-azure-win2016",
    "pamp-test-deploy",
    "AzurefilesJoinDomain",
    "azure-policies",
    "oktaCICDstack",
    "pupe-agent-windows-install",
    "azure-firewalls",
    "Runbooks",
    "icca-stack",
    "azure-labs",
    "dxc_original_makemanage",
    "RGCreate",
    "acon",
    "vmss_windows_iis_app_gateway",
    "HelloWorldDemo2021",
    "vmsampletemplate"
]
#source_org=sys.argv[1]
#target_org=sys.argv[2]

source_org = "ictazurepipeline"
target_org = "sydney-uni-ict"

hostname = os.getenv("GHES_HOSTNAME")
token_ghes = os.getenv("GH_SOURCE_PAT")
token_gh = os.getenv("GH_PAT")

# graphql API settings
headers_ghes = {'Authorization': f'token {token_ghes}'}
headers_gh = {'Authorization': f'token {token_gh}'}
graphql_endpoint_ghes = f'https://{hostname}/api/graphql'
graphql_endpoint_gh = 'https://api.github.com/graphql'

# REST API settings
gh = Github(token_gh)
ghes = Github(base_url=f'https://{hostname}/api/v3', login_or_token=token_ghes)

####### working
#To check the token expiry

repo_lengths = [len(s) for s in repo_list]
longest_repo_len=max(repo_lengths)
source_org_len=len(source_org)
target_org_len=len(target_org)

print("Check org membership")
print("--------------------")
try:
    for member in ghes.get_organization("CyberSecurity").get_members():
        user=ghes.get_user().login
        if member.login==user:
            if member.site_admin:
                print("admin of the org")
            else:
                print("NOT admin for org")
except Exception as e:
    print("Status      : NOT WORKING")
    print("Status code :",e.status)
    if e.status == 401:
        reason = "Bad credentials"
    else:
        reason = e.data
    print("Reason      :", reason)
    exit()

# print("Source Token Status")
# print("-------------------")
# try:
#     print("user :", ghes.get_user().login)
#     print("Source Token is ACTIVE")
# except Exception as e:
#     print("Status      : NOT WORKING")
#     print("Status code :",e.status)
#     if e.status == 401:
#         reason = "Bad credentials"
#     else:
#         reason = e.data
#     print("Reason      :", reason)
#     exit()

# print("\n" * 2)
# print("Target Token Status")
# print("-------------------")
# try:
#     print("user :", gh.get_user().login)
#     print("Target Token is ACTIVE")
# except Exception as e:
#     print("Status      : NOT WORKING")
#     print("Status code :",e.status)
#     if e.status == 401:
#         reason = "Bad credentials"
#     else:
#         reason = e.data
#     print("Reason      :", reason)
#     exit()

# #TO check the token access to organisation

# print("\n" * 2)
# print("Token access to Source Org")
# print("--------------------------")
# try:
#     source_org_obj=ghes.get_organization(source_org)
#     print ("Token has access to ",source_org)
# except Exception as e:
#     print ("Status      : NO Access")
#     print ("Status Code :", e.status)
#     if e.status == 404:
#         reason = "Organisation Not Found"
#     else:
#         reason = e.data
#     print("Reason      :", reason)
#     exit()

# print("\n" * 2)
# print("Token access to Target Org")
# print("--------------------------")
# try:
#     target_org_obj=gh.get_organization(target_org)
#     print ("Token has access to ",target_org)
# except Exception as e:
#     print ("Status      : NO Access")
#     print ("Status Code :", e.status)
#     if e.status == 404:
#         reason = "Organisation Not Found"
#     else:
#         reason = e.data
#     print("Reason      :", reason)
#     exit()

# print("\n" * 2)
# print("CHECK for repo in Source and Target Organisation")
# print("------------------------------------------------")
# print(" ")
# print(f"{'SOURCE ORG':<{source_org_len+1}}" "|" f"{' TARGET ORG':<{target_org_len+2}}" "|" f"{' REPO NAME':<{longest_repo_len+2}}" "|" " REPO IN SOURCE "  "|" " REPO IN TARGET " "|" " REPO STATUS " "|" " SIZE STATUS " "|" )
# print("-" * 126)

# for repo in repo_list:
#     try:
#         source_org_obj=ghes.get_organization(source_org)
#         source_org_obj.get_repo(repo)
#         repo_size=source_org_obj.get_repo(repo).size
#         src_repo_found="REPO FOUND    "
#         src_repo_status="OK"
#         if repo_size > 2000000:
#             repo_size_status="> 2GB      "
#         else:
#             repo_size_status="OK         "
#     except Exception as e:
#         src_repo_found="REPO NOT FOUND"
#         src_repo_status="CHECK"
#         repo_size_status="N/A        "
#     try:
#         target_org_obj=gh.get_organization(target_org)
#         target_org_obj.get_repo(repo)
#         tar_repo_found="REPO FOUND    "
#         tar_repo_status="CHECK"
#     except Exception as e:
#         tar_repo_found="REPO NOT FOUND"
#         tar_repo_status="OK"
#     if src_repo_status == "OK" and tar_repo_status == "OK":
#         repo_status="   OK      "
#     else:
#         repo_status="   CHECK   "
#     print(f"{source_org:<{source_org_len}}","|",f"{target_org:<{target_org_len}}","|",f"{repo:<{longest_repo_len}}","|",src_repo_found,"|",tar_repo_found,"|",repo_status,"|",repo_size_status,"|")
