#!/bin/bash
#########################################################################################
# This script checks the tokens expire date for 
# 1: Nobl9 and Dynatrace Integration token.
# 2: Nobl9 and Splunk Integration token.
#
# Local test: 
#  1. Set proper permission to read secret.
#  2. Check Dynatrace token: source helpers/validate_token.sh dynatrace
#  3. Check Splunk token: source helpers/validate_token.sh splunk
#########################################################################################
set -euo pipefail

APP="${1}"
ENV="${ENV:-nonprod}"

if [[ ${APP} != "dynatrace" ]] && [[ ${APP} != "splunk" ]]; then 
    echo "Incorrect APP ${APP}, should be [splunk ] or [dynatrace],existing!"
    exit 1
fi

if [[ ${ENV} != "nonprod" ]] && [[ ${ENV} != "prod" ]]; then 
    echo "Incorrect Env ${ENV}, should be [nonprod] or [prod], existing!"
    exit 1
fi

echo "[+]🍋 Env: [ ${ENV} ]"
echo "[+]🍋 APP: [ ${APP} ]"

TODAY_EPOCH=$(date +%s)
TWO_WEEKS_EPOCH="1209600" # 14 days in seconds

# Function to validate date
function getDynatraceTokenInfo() {
    # Get Master Token based on Env name
    if [[  "${ENV}" == "nonprod" ]]; then
        N9_DT_MASTER_TOKEN_GSM_PATH="projects/anz-x-monitoring-np-760c09/secrets/anzx-nobl9-dyna-api-key-master/versions/latest"
        DT_API_URL="https://ten54602.live.dynatrace.com/api/v2/apiTokens"
        N9_DT_INTEG_TOKEN_ID=$(jq -r .dynatrace_token_id_nonprod helpers/token_id.json)
    elif  [[  "${ENV}" == "prod" ]]; then
        N9_DT_MASTER_TOKEN_GSM_PATH="projects/anz-x-monitoring-prod-9755ba/secrets/anzx-nobl9-dyna-api-key-master/versions/latest"
        DT_API_URL="https://wen88490.live.dynatrace.com/api/v2/apiTokens"
        N9_DT_INTEG_TOKEN_ID=$(jq -r .dynatrace_token_id_prod helpers/token_id.json)
    fi

    echo "[-]    N9_DT_MASTER_TOKEN_GSM_PATH is: [ ${N9_DT_MASTER_TOKEN_GSM_PATH} ]"
    echo "[-]    DYNATRACE_API_URL is : [ ${DT_API_URL} ]"
    echo "[-]    N9_DT_INTEG_TOKEN_ID is: [ ${N9_DT_INTEG_TOKEN_ID} ]"

    N9_DT_MASTER_TOKEN_SECRET=$(gcloud secrets versions access "${N9_DT_MASTER_TOKEN_GSM_PATH}")
    
    N9_DT_EXP_DATE=$(curl -X GET "${DT_API_URL}/${N9_DT_INTEG_TOKEN_ID}" \
        -H "accept: application/json; charset=utf-8" \
        -H "Authorization: Api-Token ${N9_DT_MASTER_TOKEN_SECRET}" | jq -r .expirationDate)
    N9_DT_EXP_DATE_EPOCH=$(date -d "${N9_DT_EXP_DATE}" +"%s")

    echo "[-]    N9_DT_EXP_DATE is: [ ${N9_DT_EXP_DATE} ]"
    echo "[-]    N9_DT_EXP_DATE_EPOCH is [ ${N9_DT_EXP_DATE_EPOCH} ]"

}

function getSplunkTokenInfo() {
    SPLUNK_API_URL="https://sh-1059341257120334706.anzx.splunkcloud.com:8089/services/authorization/tokens"
    if [[  "${ENV}" == "nonprod" ]]; then
        N9_SP_MASTER_TOKEN_GSM_PATH="projects/anz-x-monitoring-np-760c09/secrets/anzx-nobl9-splunk-token-master/versions/latest"
        N9_SP_INTEG_TOKEN_ID=$(jq -r .splunk_token_id_nonprod helpers/token_id.json)
    elif  [[  "${ENV}" == "prod" ]]; then
        N9_SP_MASTER_TOKEN_GSM_PATH="projects/anz-x-monitoring-prod-9755ba/secrets/anzx-nobl9-splunk-token-master/versions/latest"
        N9_SP_INTEG_TOKEN_ID=$(jq -r .splunk_token_id_prod helpers/token_id.json)
    fi

    echo "[-]    N9_SP_MASTER_TOKEN_GSM_PATH is: [ ${N9_SP_MASTER_TOKEN_GSM_PATH} ]"
    echo "[-]    SPLUNK_API_URL is : [ ${SPLUNK_API_URL} ]"
    echo "[-]    N9_SP_INTEG_TOKEN_ID is: [ ${N9_SP_INTEG_TOKEN_ID} ]"

    N9_SP_MASTER_TOKEN_SECRET=$(gcloud secrets versions access "${N9_SP_MASTER_TOKEN_GSM_PATH}")

    N9_SP_EXP_DATE_EPOCH=$(curl -X GET -H "Authorization: Splunk ${N9_SP_MASTER_TOKEN_SECRET}" ${SPLUNK_API_URL} \
        -d id="${N9_SP_INTEG_TOKEN_ID}"  -d output_mode=json | jq -r '.entry[].content.claims.exp')

    N9_SP_EXP_DATE=$(date -d @"${N9_SP_EXP_DATE_EPOCH}")
    echo "[-]    N9_SP_EXP_DATE is: [ ${N9_SP_EXP_DATE} ]"
    echo "[-]    N9_SP_EXP_DATE_EPOCH is [ ${N9_SP_EXP_DATE_EPOCH} ]"
}

function checkToken() {

    echo "[+]"
    echo "[+] Validating ${ENV} Dynatrace Token ..."
    echo "[+]"

    if [[  "${APP}" == "dynatrace" ]]; then
        getDynatraceTokenInfo

        TOKEN_ID="${N9_DT_INTEG_TOKEN_ID}"
        EXP_DATE="${N9_DT_EXP_DATE}"
        EXP_DATE_EPOCH=${N9_DT_EXP_DATE_EPOCH}
        
    elif  [[  "${APP}" == "splunk" ]]; then
        getSplunkTokenInfo

        TOKEN_ID="${N9_SP_INTEG_TOKEN_ID}"
        EXP_DATE="${N9_SP_EXP_DATE}"
        EXP_DATE_EPOCH="${N9_SP_EXP_DATE_EPOCH}"
    fi
    
    echo ""
    echo "[+] ==============================================================="
    echo "[+] Today is: [ $(date '+%Y-%m-%d')], Epoch time is: [ $TODAY_EPOCH ]"
    echo "[+] The ${APP} token expire day is [ ${EXP_DATE} ], EXP_DATE_EPOCH is [ ${EXP_DATE_EPOCH} ]"

    # Exit with code 1 if token will expire in two weeks.
    if [[ ${TODAY_EPOCH} -gt  $(( EXP_DATE_EPOCH - TWO_WEEKS_EPOCH )) ]]; then 
        echo "[+]"
        echo "[+] 🦞🦞🦞🦞 ${APP} Token [ ${TOKEN_ID} ] will expire in two weeks!🦞🦞🦞🦞"
        echo "[+]"
        exit 1
    else
        echo "[+]"
        echo "[+] 🦁🦁🦁🦁 Token validation completed! No action required. 🦁🦁🦁🦁"
        echo "[+]"
    fi
}

checkToken