#!/bin/bash
#########################################################################################
# This script will be used to Download Dynatrace ActiveGate/OneAgent and upload to bucket
# Strongly suggest to run this script without VPN on local.
# Usage: 
#   export DT_PAAS_TOKEN_NP=<DT_PAAS_TOKEN_NP>
#   export DT_PAAS_TOKEN_PROD=<DT_PAAS_TOKEN_PROD>
#   bash download-ag-oa-script.sh [option]
#
# The options are: [ check|all|download_all|download_oa|download_ag|upload_all|upload_oa|upload_ag ]
#########################################################################################

# Global variables
RED="\033[0;31m" # Red Color
BLUE="\033[0;34m" # Blue Color
GREEN="\033[0;32m" # Green Color
NC="\033[0m" # No Color

if [ -z "${1}" ];then echo "Error: option is not provided.
Usage:
   export DT_PAAS_TOKEN_NP=<DT_PAAS_TOKEN_NP>
   export DT_PAAS_TOKEN_PROD=<DT_PAAS_TOKEN_PROD>
   bash download-ag-oa-script.sh [option]
The options are: [
    check           checks both OA and AG versions
    all             check and download both OA and AG versions and then upload them to bucket
    download_all    downlaods both OA and AG version
    download_oa     downloads OA version
    download_ag     downloads AG version
    upload_all      uploads both OA and AG versions
    upload_oa       uploads OA version
    upload_ag       uploads AG version]";exit 1;fi
if [ -z "${DT_PAAS_TOKEN_NP}" ];then echo "DT_PAAS_TOKEN_NP is not provided!";exit 1;fi
if [ -z "${DT_PAAS_TOKEN_PROD}" ];then echo "DT_PAAS_TOKEN_PROD is not provided!";exit 1;fi

# Common vars
BINARY_PATH="${BINARY_PATH:-/tmp/}"
TEMP_DIR="${BINARY_PATH:-/tmp/}"
BUCKET_NAME="anz-x-monitoring-dev-cf32e8-install-files"

# ####################
# Functions
# ####################
check_version () {
    #############################################
    # get OA version
    #############################################
    SAAS_ENVIRONMENT_TENANTID="ten54602"
    API_URL="https://${SAAS_ENVIRONMENT_TENANTID}.live.dynatrace.com/api"
    curl -sS -H "Authorization: Api-Token ${DT_PAAS_TOKEN_NP}" \
        -o ${TEMP_DIR}/oa_version.txt \
        -L "${API_URL}/v1/deployment/installer/agent/versions/unix/default?flavor=default&arch=x86"

    LATEST_OA_VERSION=$(cat ${TEMP_DIR}/oa_version.txt | jq -r  '.availableVersions|sort[]' | tail -1)
    DEPLOY_ONEAGENT_VERSION=${LATEST_OA_VERSION}
    ONEAGENT_VERSION_SHORT=$(echo $LATEST_OA_VERSION |  rev | cut -d '.' -f 2- | rev)

    echo "#############################################"
    echo -e "The latest OA version is: [ ${GREEN}$LATEST_OA_VERSION${NC} ]"
    echo -e "The latest OA short version is: [ ${GREEN}$ONEAGENT_VERSION_SHORT${NC} ]"
    echo ""
    

    #############################################
    # Get AG version
    #############################################
    curl -sS -H "Authorization: Api-Token ${DT_PAAS_TOKEN_NP}" \
        -o ${TEMP_DIR}/ag_version.txt \
        -L "${API_URL}/v1/deployment/installer/gateway/versions/unix"

    LATEST_AG_VERSION=$(cat ${TEMP_DIR}/ag_version.txt | jq -r  '.availableVersions|sort[]' | tail -1)
    DEPLOY_ACTIVEGATE_VERSION=${LATEST_AG_VERSION}
    ACTIVEGATE_VERSION_SHORT=$(echo $LATEST_AG_VERSION |  rev | cut -d '.' -f 2- | rev)
    echo "#############################################"
    echo -e "The latest AG version is: [ ${GREEN}$LATEST_AG_VERSION${NC} ]"
    echo -e "The latest AG short version is: [ ${GREEN}$ACTIVEGATE_VERSION_SHORT${NC} ]"
    echo ""

}

verification() {
#    p_filename=$2
    if [ ! -f ${BINARY_PATH}/dt-root.cert.pem ]; then
        echo "Downloading Dynatrace CA code-signing certificate..."
#        curl -sS -o ${BINARY_PATH}/dt-root.cert.pem -L "https://ca.dynatrace.com/dt-root.cert.pem"
        wget "https://ca.dynatrace.com/dt-root.cert.pem" -O ${BINARY_PATH}/dt-root.cert.pem
    fi

    ( echo 'Content-Type: multipart/signed; protocol="application/x-pkcs7-signature"; micalg="sha-256"; boundary="--SIGNED-INSTALLER"'; echo ; echo ; echo '----SIGNED-INSTALLER' ;
    cat "${BINARY_PATH}/${p_filename}" ) |
    openssl cms -verify -CAfile "${BINARY_PATH}/dt-root.cert.pem" > /dev/null
    if [ $? != 0 ]; then echo "${p_filename} verifiction check failed!";exit 1;fi
    echo "Installation file ${p_filename} verifiction completed successfully!"
}

##############################
# Download OA
##############################
download-oa-np () {
    # NONPROD:
    SAAS_ENVIRONMENT_TENANTID=ten54602
    API_URL="https://${SAAS_ENVIRONMENT_TENANTID}.live.dynatrace.com/api"
    OA_FILE_NAME_NP="Dynatrace-OneAgent-Linux-${ONEAGENT_VERSION_SHORT}.sh"

    echo "Download OA Nonprod: starting... "
    curl -sS -H "Authorization: Api-Token ${DT_PAAS_TOKEN_NP}" \
        -o ${BINARY_PATH}/${OA_FILE_NAME_NP} \
        -L "${API_URL}/v1/deployment/installer/agent/unix/default/version/${DEPLOY_ONEAGENT_VERSION}"

    echo "************************************************"
    echo "Check NonProd OA version and verfiy the package"
    cat ${BINARY_PATH}/${OA_FILE_NAME_NP} | grep "AGENT_INSTALLER_VERSION="
#    verification ${OA_FILE_NAME_NP}
    echo "************************************************"
}

download-oa-prod () {
    # PROD:
    SAAS_ENVIRONMENT_TENANTID=wen88490
    API_URL="https://${SAAS_ENVIRONMENT_TENANTID}.live.dynatrace.com/api"
    OA_FILE_NAME_PROD="Dynatrace-OneAgent-Linux-${ONEAGENT_VERSION_SHORT}-Prod.sh"

    echo "Download OA Prod: starting... "
    curl -sS -H "Authorization: Api-Token ${DT_PAAS_TOKEN_PROD}" \
        -o ${BINARY_PATH}/${OA_FILE_NAME_PROD} \
        -L "${API_URL}/v1/deployment/installer/agent/unix/default/version/${DEPLOY_ONEAGENT_VERSION}"
    
    echo "************************************************"
    echo "Check Prod OA version and verfiy the package"
    cat ${BINARY_PATH}/${OA_FILE_NAME_PROD} | grep "AGENT_INSTALLER_VERSION="
#    verification ${OA_FILE_NAME_PROD}
    echo "************************************************"

}
##############################
# Download AG
##############################
download-ag-np () {
    # NONPROD:
    SAAS_ENVIRONMENT_TENANTID=ten54602
    API_URL="https://${SAAS_ENVIRONMENT_TENANTID}.live.dynatrace.com/api"
    AG_FILE_NAME_NP="Dynatrace-ActiveGate-Linux-${ACTIVEGATE_VERSION_SHORT}.sh"

    echo "Download ActiveGate Nonprod: starting... "
    curl -sS -H "Authorization: Api-Token ${DT_PAAS_TOKEN_NP}" \
        -o ${BINARY_PATH}/${AG_FILE_NAME_NP} \
        -L "${API_URL}/v1/deployment/installer/gateway/unix/version/${DEPLOY_ACTIVEGATE_VERSION}?arch=x86&flavor=default"

    echo "************************************************"
    echo "Check  NonProd AG version and verfiy the package"
    cat ${BINARY_PATH}/${AG_FILE_NAME_NP} | grep "ACTIVEGATE_VERSION_SHORT="
#    verification ${AG_FILE_NAME_NP}
    echo "************************************************"
}

download-ag-prod () {
    # PROD:
    SAAS_ENVIRONMENT_TENANTID=wen88490

    API_URL="https://${SAAS_ENVIRONMENT_TENANTID}.live.dynatrace.com/api"
    AG_FILE_NAME_PROD="Dynatrace-ActiveGate-Linux-${ACTIVEGATE_VERSION_SHORT}-Prod.sh"

    echo "Download ActiveGate Prod: starting... "
    curl -sS -H "Authorization: Api-Token ${DT_PAAS_TOKEN_PROD}" \
        -o ${BINARY_PATH}/${AG_FILE_NAME_PROD} \
        -L "${API_URL}/v1/deployment/installer/gateway/unix/version/${DEPLOY_ACTIVEGATE_VERSION}?arch=x86&flavor=default"

    echo "************************************************"
    echo "Check  Prod AG version and verfiy the package"
    cat ${BINARY_PATH}/${AG_FILE_NAME_PROD} | grep "ACTIVEGATE_VERSION_SHORT="
#    verification ${AG_FILE_NAME_PROD}
    echo "************************************************"

}

##############################
# Upload to bucket
##############################

upload_prod () {
 gcloud config set project anz-x-monitoring-dev-cf32e8
 AG_FILE_NAME_PROD="Dynatrace-ActiveGate-Linux-${ACTIVEGATE_VERSION_SHORT}-Prod.sh"
# OA_FILE_NAME_PROD="Dynatrace-OneAgent-Linux-${ONEAGENT_VERSION_SHORT}-Prod.sh"

 echo "Uploading ${BINARY_PATH}/${AG_FILE_NAME_PROD}"
 gsutil cp ${BINARY_PATH}/${AG_FILE_NAME_PROD} gs://${BUCKET_NAME}/${AG_FILE_NAME_PROD}

# echo "Uploading ${BINARY_PATH}/${OA_FILE_NAME_PROD}"
# gsutil cp ${BINARY_PATH}/${OA_FILE_NAME_PROD} gs://${BUCKET_NAME}/${OA_FILE_NAME_PROD}
}

upload_oa () {
 gcloud config set project anz-x-monitoring-dev-cf32e8
 OA_FILE_NAME_NP="Dynatrace-OneAgent-Linux-${ONEAGENT_VERSION_SHORT}.sh"
 OA_FILE_NAME_PROD="Dynatrace-OneAgent-Linux-${ONEAGENT_VERSION_SHORT}-Prod.sh"

 echo "Uploading ${BINARY_PATH}/${OA_FILE_NAME_NP}"
 gsutil cp ${BINARY_PATH}/${OA_FILE_NAME_NP}   gs://${BUCKET_NAME}/${OA_FILE_NAME_NP}

 echo "Uploading ${BINARY_PATH}/${OA_FILE_NAME_PROD}"
 gsutil cp ${BINARY_PATH}/${OA_FILE_NAME_PROD} gs://${BUCKET_NAME}/${OA_FILE_NAME_PROD}
}

upload_ag () {
  gcloud config set project anz-x-monitoring-dev-cf32e8
  AG_FILE_NAME_NP="Dynatrace-ActiveGate-Linux-${ACTIVEGATE_VERSION_SHORT}.sh"
  AG_FILE_NAME_PROD="Dynatrace-ActiveGate-Linux-${ACTIVEGATE_VERSION_SHORT}-Prod.sh"

  echo "Uploading ${BINARY_PATH}/${AG_FILE_NAME_NP}"
  gsutil cp ${BINARY_PATH}/${AG_FILE_NAME_NP}   gs://${BUCKET_NAME}/${AG_FILE_NAME_NP}

  echo "Uploading ${BINARY_PATH}/${AG_FILE_NAME_PROD}"
  gsutil cp ${BINARY_PATH}/${AG_FILE_NAME_PROD} gs://${BUCKET_NAME}/${AG_FILE_NAME_PROD}
}


##############################
# MAIN
##############################
action=$1

check_version

case ${action} in
check)
    # Moved the check to the main as the pre-req for all other steps 
    ;;
download_all)
    download-oa-np
    download-oa-prod
    download-ag-np
    download-ag-prod
    ;;
download_prod_all)
    download-oa-prod
    download-ag-prod
    ;;
download_oa)
    download-oa-np
    download-oa-prod
    ;;
download_ag)
    download-ag-np
    download-ag-prod
    ;;
upload_all)
    upload_oa
    upload_ag
    ;;
upload_oa)
    upload_oa
    ;;
upload_ag)
    upload_ag
    ;;
upload_prod)
    upload_prod
    ;;
download-ag-prod)
    download-ag-prod
    ;;
verification)
    p_filename=$2
    verification
    ;;
all)
    download-oa-np
    download-oa-prod
    download-ag-np
    download-ag-prod
    upload_oa
    upload_ag
    ;;
*)
    echo "** Unknown option: ${action} !"
    echo "Usage: bash download-ag-oa-script.sh [option] ... "
    echo "The options are: [ check|all|download_all|download_oa|download_ag|upload_all|upload_oa|upload_ag ]"
    exit 1
    ;;
esac
