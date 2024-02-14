#################################################################################################################
# This script helps to perform following operations
# 1. Create and download service_account key
# 2. encrypt the downloaded file with a random PASSWORD
# 3. Print that password on console
# 4. Delete the downloaded json file
#
# To run this script
# gcloud and 7zip tools are expected to be pre-installed in terminal
# 1. Login to gcloud using the command → gcloud auth login
# 2. Set the project id → gcloud config set project "<project id>"
# 3. Download this bash script and save
# 4. chmod u+x download_encrypt_gcp_sa_key.sh  → provide executable permissions
# 5. ./download_encrypt_gcp_sa_key.sh '<sa-key-file-name>.json' '<sa-name>@<gcp-project-id>.iam.gserviceaccount.com'
# 6. encrypted file service-account-key.zip will be created and password is printed in the console
####################################################################################################################


#!/bin/bash
gcloud iam service-accounts keys create $1 --iam-account=$2
PASSWORD=$(openssl rand -base64 32)
if [ -f "$1" ]; then
    echo "$1 exists."
    7z a -tzip -mem=AES256 -p$PASSWORD service-account-key.zip $1
    echo "PASSWORD :"$PASSWORD
    echo "removing the original key file"
    rm $1
else
    echo "$1 does not exist."
fi
