import os
import glob
import time
import random
import json
import requests
import re
from datetime import datetime, timedelta

stream_name = "uos-gh-migration-prod"

# Cloud Loki
grafana_url=os.environ['GRAFANA_URL']
grafana_user=os.environ['GRAFANA_USER']
grafana_password=os.environ['GRAFANA_PASSWORD']
loki_url = f"https://{grafana_user}:{grafana_password}@{grafana_url}/loki/api/v1/push"

def push_log_to_loki(log_entry):
    headers = {"Content-Type": "application/json"}
    payload_json = json.dumps(log_entry)

    response = requests.post(loki_url, headers=headers, data=payload_json)
    if response.status_code != 204:
        print(f"Failed to push log entry to Loki: {response.status_code} - {response.text}")

# log_directory = os.getcwd()
#log_directory = "./testing_new_logs"
log_directory = "./new-missed-logs"
#log_directory = "."

#log_directory = os.getcwd()

print(log_directory)
print(stream_name)

for log_file in glob.glob(os.path.join(log_directory, "*.octoshift.log")):
    log_stream = os.path.basename(log_file)
    print(f"Processing log file: {log_file}")
    
    # To determine the source repo name, we need to look at the log file
    # if the source repo is not found, we need to look for github repo followed by migration finish

    # Search file for 'SOURCE REPO: ' and 'GITHUB REQUEST ID: ' to extract labels
    repo_name = ""
    github_id = ""
    src_org = ""
    with open(log_file, "r") as file:
        for line in file:
            if "SOURCE REPO: " in line:
                repo_name = line.strip().split("SOURCE REPO: ")[1]
            if "GITHUB SOURCE ORG: " in line:
                src_org = line.strip().split("GITHUB SOURCE ORG: ")[1]
            if "GITHUB REQUEST ID: " in line:
                github_id = line.strip().split("GITHUB REQUEST ID: ")[1]
            if repo_name != "" and github_id != "" and src_org != "":
                break

    with open(log_file, "r") as file:
        for line in file:
            # Considering only Lines starting with [
            if line.startswith("["):
                
                first_line = "N"
                last_line = "N"
                # Get the first line of the log message
                if "GITHUB SOURCE ORG: " in line:
                    first_line = "Y"

                # Extract the severity from the log message
                severity_match = re.search(r'\[([A-Z]+)\]', line)

                if severity_match:
                    severity = severity_match.group(1)
                else:
                    print("Severity not found in the log message.")

                # Get the last line of the successful message
                if "State: SUCCEEDED" in line or severity == "ERROR":
                    last_line = "Y"

                ingest_time_ns = int(time.time() * 1e9)

                log_entry_1 = {
                    "streams": [
                        {
                            "stream": {
                                "stream_name": f"{stream_name}",
                                "log_file": f"{log_stream}",
                                "github_id": f"{github_id}",
                                "src_org": f"{src_org}",
                                "repo_name": f"{repo_name}",
                                "severity": f"{severity}"
                            },
                            "values": [[f"{ingest_time_ns}", f"{line}"]]
                        }
                    ]
                }

                log_entry_2 = {
                    "streams": [
                        {
                            "stream": {
                                "stream_name": f"{stream_name}-full",
                                "log_file": f"{log_stream}",
                                "github_id": f"{github_id}",
                                "src_org": f"{src_org}",
                                "repo_name": f"{repo_name}",
                                "severity": f"{severity}"
                            },
                            "values": [[f"{ingest_time_ns}", f"{line}"]]
                        }
                    ]
                }

                #writing only first and last lines to loki stream
                if first_line == "Y" or last_line == "Y":
                    # print(log_entry_1)
                    push_log_to_loki(log_entry_1)

                #writing all log lines to another loki steam, stream name is appended with full
                # print(log_entry_2)
                push_log_to_loki(log_entry_2)

print("Log processing complete.")
