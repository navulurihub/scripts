#!/bin/bash
set -e

PROD_UTILITY_PROJECT=anz-x-services-prod-41d6dd
PROD_BASTION_PROJECT=anz-ecp-bastion-prod-4d92d2
NONPROD_UTILITY_PROJECT=anz-x-services-staging-f9c3d9
NONPROD_BASTION_PROJECT=anz-ecp-bastion-np-c011dc

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
RST="$(tput sgr0)"

# select environment based on parameter
if [[ "$1" == "prod" ]]; then
    UTILITY_PROJECT=$PROD_UTILITY_PROJECT
    BASTION_PROJECT=$PROD_BASTION_PROJECT
elif [[ "$1" == "nonprod" ]]; then
    UTILITY_PROJECT=$NONPROD_UTILITY_PROJECT
    BASTION_PROJECT=$NONPROD_BASTION_PROJECT
else
    echo "${RED}USAGE: $0 [prod|nonprod]${RST}"
    exit 1
fi

# version check
SCRIPT_VERSION=5
LATEST_URL=https://artifactory.gcp.anz:443/artifactory/anzx-binaries/utility/login-bastion.sh
LATEST_VERSION=$(curl -s $LATEST_URL | awk -F'=' '$1=="SCRIPT_VERSION"{print $2}')
if [[ "$SCRIPT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "This script is version ${SCRIPT_VERSION} which is the latest. ${GREEN}Nice job!${RST}"
else
    echo "${RED}WARNING: This script is version ${SCRIPT_VERSION} - please update to version $LATEST_VERSION${RST} at $LATEST_URL"
fi

# check gcloud version
currentver="$(gcloud version | awk '/Google Cloud SDK/ {print $4}')"
function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }
if [ "$(version "$currentver")" -ge "$(version "365.0.0")" ]; then
    echo "current gcloud version is $currentver"
else
    echo "${RED}ERROR! current gcloud version is $currentver, gcloud version should be greater than 365.0.0${RST}"
    exit 1
fi

# check gcloud user login
gclouduser=$(gcloud config list account --format "value(core.account)")
if [[ "$?" != "0" ]]; then
    echo "gcloud login command failed."
elif [[ "$gclouduser" ]]; then
    echo "$gclouduser is logged in gcloud account"
else
    echo "${RED}No user is logged in gcloud account.${RST}"
    exit 1
fi

# find a random utility box
echo -n "Finding utility box... "
UTILITY_ARGS="--region=australia-southeast1 --project=${UTILITY_PROJECT}"
UTILITY_VMS=($(gcloud compute instance-groups list-instances utility-vm-ig $UTILITY_ARGS --filter="status=running" --format="value(NAME)"))
UTILITY_NUM=$(($RANDOM % ${#UTILITY_VMS[@]}))
UTILITY_VM="${UTILITY_VMS[$UTILITY_NUM]}"
UTILITY_IP=$(gcloud compute instances describe "${UTILITY_VMS[$UTILITY_NUM]}" --format="value(networkInterfaces.networkIP)" --project=${UTILITY_PROJECT})
echo "found $UTILITY_VM ($UTILITY_IP)"


# find a random bastion host
echo -n "Finding bastion box... "
BASTION_ARGS_VM_LIST="--region=australia-southeast1 --project=${BASTION_PROJECT}"
BASTION_VMS=($(gcloud compute instance-groups list-instances ssh-bastion-group-manager $BASTION_ARGS_VM_LIST --filter="status=running" --format="value(NAME)"))
BASTION_NUM=$(($RANDOM % ${#BASTION_VMS[@]}))
BASTION_VM="${BASTION_VMS[$BASTION_NUM]}"
# BASTION_IP=$(gcloud compute instances describe "${BASTION_VMS[$BASTION_NUM]}" --format="value(networkInterfaces.networkIP)" $BASTION_ARGS)
echo "found $BASTION_VM"

BASTION_VM_ZONE=$(gcloud compute instances list --project=$BASTION_PROJECT --filter="name=$BASTION_VM" --format="value(ZONE)")
BASTION_ARGS="--zone=$BASTION_VM_ZONE --project=${BASTION_PROJECT}"

# trigger GCE key generation if it doesn't exist
SSH_KEY=~/.ssh/google_compute_engine
if [[ ! -f $SSH_KEY ]]; then
    # generate key if not exists
    echo "${SSH_KEY} does not exist - creating"
    gcloud compute ssh ${BASTION_VM} ${BASTION_ARGS} --tunnel-through-iap --dry-run --quiet
fi

# start ssh-agent, and load the GCE key (if not already)
echo "Adding GCE key to SSH agent..."
ssh-add $SSH_KEY

# login to the bastion host (with ssh-agent forwarding)
echo
echo
echo "############################################################################"
echo "### login to GCP using command below (paste the emitted command/url to your local machine, and past result back to script)"
echo "${GREEN}cloudlogin${RST}"
echo
echo "### then get credentials for example:"
if [[ "$1" == "prod" ]]; then
    echo "${GREEN}gcloud container clusters get-credentials anz-x-apps-prod-gke --region australia-southeast1 --project anz-x-apps-prod-1e6a27${RST}"
    echo "${GREEN}gcloud container clusters get-credentials anz-x-services-prod-gke --region australia-southeast1 --project anz-x-services-prod-41d6dd${RST}"
    echo "${GREEN}gcloud container clusters get-credentials anz-x-perimeter-prod-gke --region australia-southeast1 --project anz-x-perimeter-prod-6a7b83${RST}"
    echo "${GREEN}gcloud container clusters get-credentials anz-x-winapps-prod-gke --region australia-southeast1 --project anz-x-winapps-prod-b2e26a${RST}"
    echo "${GREEN}gcloud container clusters get-credentials anz-x-ingress-prod-beta --region australia-southeast1 --project anz-x-ingress-prod-947262${RST}"
    echo "${GREEN}gcloud container clusters get-credentials anz-x-forgeds-prod-0 --region australia-southeast1 --project anz-x-forgeds-prod-b5798c${RST}"
    echo "${GREEN}gcloud container clusters get-credentials anz-x-forgeds-prod-1 --region australia-southeast1 --project anz-x-forgeds-prod-b5798c${RST}"
else
    echo "${GREEN}gcloud container clusters get-credentials anz-x-apps-np-gke --region australia-southeast1 --project anz-x-apps-np-e1bb39${RST}"
    echo "${GREEN}gcloud container clusters get-credentials anz-x-services-np-gke --region australia-southeast1 --project anz-x-services-np-5c476f${RST}"
fi
echo "############################################################################"
echo
echo

# Use an expect script to login to the bastion host (with ssh-agent forwarding)
# then send the commands to jump to the utility VM
expect -c 'set timeout -1
spawn gcloud compute ssh '"${BASTION_VM}"' --tunnel-through-iap '--ssh-flag="-q"' '"${BASTION_ARGS}"' -- -A
expect -re "(%|#|\\$) $"
send "ssh -o StrictHostKeyChecking=no -q '"${UTILITY_IP}"'\r"
interact
'