#################################################################################################
# This script was created to help update oneagent versions on Harness Delegates.
# 1. Update dir_name to point towards the platform-harness-delegates repo on your local machine
# 2. For NONPROD or PROD PRs simply uncomment/comment the correct env Vars section. So only
#    one env vars gets applied.
# 3. Update previous_oneagent_version and new_oneagent_version variables with correct values.
# 4. Run the script. This should edit all applicable config files for the PR.
# 
# How this script works:
# - Script searches for grep_string in a file and will edit all files containing that grep_string 
# - The initial state is the lines to be edited.
# - The after state is what those lines should become.
# - The initial state and after state can be flipped for simple rollback.
#
#################################################################################################

import os

dir_name = "/Users/lees1/Desktop/ANZx/github/platform-harness-delegates/delegates"
list_of_file = os.listdir(dir_name)

# NONPROD Vars
grep_string = "projects/anz-x-bootstrap-np-487e09/secrets/harness-delegates-hshqms-account-secret/versions/1"
env = "np"
previous_oneagent_version = "1.227.148-e3e5772"
new_oneagent_version = "1.227.148-e3e5773"

# PROD Vars
# grep_string = "projects/anz-x-bootstrap-prod-3b7a6d/secrets/harness-delegates-hshqms-account-secret/versions/1"
# env = "prod"
# previous_oneagent_version = "1.227.148-e3e5772"
# new_oneagent_version = "1.227.148-e3e5773"

for entry in list_of_file:
    initial_state = f"""
    image: anzx-docker.artifactory.gcp.anz/observability/dynatrace/{env}/oneagent:{previous_oneagent_version}
"""
    after_state = f"""
    image: anzx-docker.artifactory.gcp.anz/observability/dynatrace/{env}/oneagent:{new_oneagent_version}
"""
    # Create full path
    dir_full_path = os.path.join(dir_name, entry)
    # If entry is a directory then get the list of files in this directory 
    if os.path.isdir(dir_full_path):
        dir_files = os.listdir(dir_full_path)
        for file in dir_files:
            file_full_path = os.path.join(dir_name, entry, file)
            if not os.path.isdir(file_full_path):
                with open(file_full_path, "r") as f:
                    file_data = f.read()
                if grep_string in file_data and entry != "platdevex":
                    # print(entry, file)
                    file_data=file_data.replace(initial_state, after_state)
                with open(file_full_path, "w") as f:
                    f.write(file_data)