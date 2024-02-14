import os
from github import Github
import csv
import argparse

hostname = os.getenv("GHES_HOSTNAME")
token_ghes = os.getenv("GH_SOURCE_PAT")
ghes = Github(base_url=f'https://{hostname}/api/v3', login_or_token=token_ghes)

# argparse settings
parser = argparse.ArgumentParser()
parser.add_argument('org_name', type=str, help='A positional argument for the name of the organisation to be scanned')
args = parser.parse_args()

if __name__ == '__main__':
    if token_ghes and hostname:
        if args.org_name:
            org_name = args.org_name
            csv_file = f'{org_name}.csv'
            header = ['org_name', 'repo_name', 'has_pages?']
            org = ghes.get_organization(org_name)
            repos = org.get_repos()
            for repo in repos:
                repo_name = repo.name
                has_pages = repo.has_pages
                data_to_write = [org_name, repo_name, has_pages]
                with open(csv_file, mode='a') as audit_report_file:
                    reconciliation_writer = csv.writer(audit_report_file, delimiter=',', quotechar='"',
                                                       quoting=csv.QUOTE_MINIMAL)
                    if os.stat(csv_file).st_size == 0:
                        reconciliation_writer.writerow(header)
                    reconciliation_writer.writerow(data_to_write)
    else:
        print('Please set your GH_SOURCE_PAT and GHES_HOSTNAME.')

