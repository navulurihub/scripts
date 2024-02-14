#!/bin/bash

# Your GitHub credentials
USERNAME="ghadmin"
ORGNAME="test-org"
TOKEN="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"

# Extract and push repositories
for tarball in $(ls *-git_archive.tar.gz); do
    repo_name=$(basename -s .tar.gz $tarball)
    echo "Processing $repo_name"

    # Extract
    mkdir -p $repo_name
    tar -xzvf $tarball -C $repo_name 
    
    # Create repository
    curl -L \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $TOKEN" \
        https://githubaws.furo.dev/api/v3/orgs/$ORGNAME/repos \
        -d '{"name":"'$repo_name'","description":"This is your first repository","homepage":"https://github.com","private":false,"has_issues":true,"has_projects":true,"has_wiki":true}'

    # Push to GitHub
    cd $repo_name
    git init
    git add .
    git commit -m "Initial commit"
    git remote add origin https://githubaws.furo.dev/$ORGNAME/$repo_name.git
    git push -u origin main

    # Clean up
    cd ..
    rm -rf $repo_name
done
