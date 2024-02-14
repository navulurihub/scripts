########################################################################################################################################
# 1. As dynatrace components image build steps are in required status, we want to skip the run when there are no updates to files
#       Reference to Required status checks —> https://github.com/anzx/github-resource-config/pull/470/files
# 2. This script is to find the list of files changed/updated between the current commit and the base commit in main branch.
# 3. Based on changed files, output variables are assigned with true or false values.
# 4. These O/P variables will help in skipping or executing the Docker build,Image scan and Docker push activities in later steps.
# 5. Condition to skip is coded in .github/workflows/activegate.yaml, .github/workflows/oneagent.yaml and .github/workflows/operator.yaml
#########################################################################################################################################
#!/usr/bin/env bash
set -e

if [[ $GITHUB_EVENT_NAME == "pull_request" ]]; then
  BRANCH=$(cat $GITHUB_EVENT_PATH | jq -r .pull_request.head.ref)
  BASE_BRANCH=$(cat $GITHUB_EVENT_PATH | jq -r .pull_request.base.ref)
  GITHUB_SHA=$(cat $GITHUB_EVENT_PATH | jq -r .pull_request.head.sha)
  git diff --name-only origin/$BASE_BRANCH...$GITHUB_SHA > files.txt
elif [[ $GITHUB_EVENT_NAME == "push" ]]; then
  BRANCH=main
  BASE_SHA=$(cat $GITHUB_EVENT_PATH | jq -r .before)
  git diff --name-only $BASE_SHA...$GITHUB_SHA > files.txt
fi

echo "<----- LIST OF FILES CHANGED ------->"
cat files.txt
echo "<----------------------------------->"
#Check are split as set-out variable is being skipped if kept in single condition
while IFS= read -r file
do
    if [[ $file = "Dockerfile" || $file = ".github/workflows/operator.yaml" || $file = "versions/operator.txt" ]]; then
       echo ">>> $file  - modified - requires operator build."
       echo "::set-output name=operator_changes::true"
       break
    else
       echo "::set-output name=operator_changes::false"
    fi
done < files.txt
while IFS= read -r file
do
    if [[ $file = "Dockerfile" || $file == ".github/workflows/oneagent.yaml" || $file = "versions/oneagent.txt" ]]; then
       echo ">>> $file  - modified - requires oneagent build."
       echo "::set-output name=oneagent_changes::true"
       break
    else
       echo "::set-output name=oneagent_changes::false"
    fi
done < files.txt
while IFS= read -r file
do
    if [[ $file = "Dockerfile" || $file == ".github/workflows/activegate.yaml" || $file == "versions/activegate.txt" ]]; then
       echo ">>> $file  - modified - requires activegate build."
       echo "::set-output name=activegate_changes::true"
       break
    else
       echo "::set-output name=activegate_changes::false"
    fi
done < files.txt