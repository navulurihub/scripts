#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1117
# The intent of this script is to enable:
# 1. Creation of service accounts
# 2. Download keys for service accounts
# 3. Bind policies required for Apigee components to the service accounts.

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# shellcheck disable=SC1090
source "${PWD}/common.sh"

# Component specific roles.
#
# NOTE: Ensure the format is <component/feature>_ROLES, where component/feature is uppercase and replace '-' with '_'.
#
APIGEE_LOGGER_ROLES="roles/logging.logWriter"
APIGEE_METRICS_ROLES="roles/monitoring.metricWriter"
APIGEE_CASSANDRA_ROLES="roles/storage.objectAdmin"
APIGEE_UDCA_ROLES="roles/apigee.analyticsAgent"
APIGEE_SYNCHRONIZER_ROLES="roles/apigee.synchronizerManager"
APIGEE_MART_ROLES="roles/apigeeconnect.Agent"
APIGEE_WATCHER_ROLES="roles/apigee.runtimeAgent"
APIGEE_DISTRIBUTED_TRACE_ROLES="roles/cloudtrace.agent"


#**
# @brief    Displays usage details.
#
usage() {
    log_error "$*\n usage: $(basename "$0")" \
        "<apigee_component> <output_dir> [gcp_project_id(optional)]\n" \
        "example: $(basename "$0") apigee-logger ./service-accounts"
}

#**
# @brief    Obtains GCP project ID from gcloud configuration and updates global variable PROJECT_ID.
#
get_project(){
    local project_id ret
    local msg="Provide GCP Project ID via command line arguments or update gcloud config: gcloud config set project <project_id>"

    project_id=$(gcloud config list core/project --format='value(core.project)'); ret=$?
    [[ ${ret} -ne 0 || -z "${project_id}" ]] && \
        usage "Failed to get project ID from gcloud config.\n${msg}"

    log_info "gcloud configured project ID is ${project_id}.\n" \
        "Press: y to proceed with creating service account in project: ${project_id}\n" \
        "Press: n to abort."
    read -r prompt
    if [[ "${prompt}" != "y" ]]; then
        usage "Aborting.\n${msg}"
    fi
    PROJECT_ID="${project_id}"
}

#**
# @brief    Checks if a service account already exists. If it does not exist creates it.
#           If it fails to create service account, it exists the script.
# @return 0 Successfully creates service account.
# @return 1 Service account already exists.
#
check_and_create_service_account(){
    local sa_name=$1
    local sa_email=$2
    local ret

    log_info "Checking if service account already exists"
    gcloud iam service-accounts describe "${sa_email}" -q > /dev/null 2>&1 ; ret=$?
    if [[ ${ret} -eq 0 ]]; then
        log_info "Service account ${sa_email} already exists."
        return 1
    fi

    log_info "Service account does not exist. Creating..."
    gcloud iam service-accounts --format='value(email)' create "${sa_name}" --project="${PROJECT_ID}"  \
        --display-name="${sa_name}" || log_error "Failed to create service account ${sa_email}"

    log_info "Successfully created service account ${sa_email}"
    return 0
}

#**
# @brief    Invokes gcloud command to download json keys.
#
download_keys(){
    local sa_name=$1
    local sa_email=$2
    local output_dir=$3
    local project_id=$4
    gcloud iam service-accounts keys create "${output_dir}/${project_id}-${sa_name}.json" \
        --iam-account="${sa_email}" || \
            log_error "Failed to download keys for service account ${sa_name}"
    log_info "JSON Key ${sa_name} was successfully download to directory $PWD."
}

#**
# @brief    Returns GCP IAM roles that are needed for a given component.
#
get_roles(){
    local comp=$1
    local role_name

    # Convert comp to upper case and '-' to '_'.
    role_name="$(echo "${comp}_ROLES" | tr '[:lower:]' '[:upper:]')"
    role_name="${role_name//-/_}"

    # Return value stored in global variable <component>_ROLES.
    echo "${!role_name}"
}

#**
# @brief    Binds component specific policy roles to service account.
#
bind_policy(){
    local sa_email=$1
    local comp=$2
    local roles

    # Obtain roles using the component name. Roles are in variables COMP_roles
    roles=$(get_roles "${comp}")
    if [[ -z "${roles}" ]]; then
        log_info "No roles found for $comp. Skipping policy binding"
    else
        log_info "Attaching ${comp} specific policy for ${sa_email}"
    fi


    # shellcheck disable=SC2068
    for role in ${roles[@]}; do
        # add the IAM policy binding for the defined project and service account
        gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
            --member serviceAccount:"${sa_email}" \
            --role "${role}" > /dev/null || \
                log_error "Failed to attach role ${role} to service account ${sa_email}"
    done

    # Display updated policy for the service account.
    gcloud projects get-iam-policy "${PROJECT_ID}"  \
        --flatten="bindings[].members" \
        --format='table(bindings.role)' \
        --filter="bindings.members:${sa_email}"
    log_info "Successfully updated roles for ${sa_email}"
}

### Start of mainline code ###

# Get service account name and component as command line arguments.
COMP=$1
OUTPUT_DIR=$2
PROJECT_ID=$3
SA_NAME=${4:-$COMP}

[[ -z "${COMP}" ]] && usage "Apigee component not defined"
[[ -z "${OUTPUT_DIR}" ]] && usage "Output directory not defined"
mkdir -p "${OUTPUT_DIR}" || usage "Unable to create directory, please check permissions and try again"

# Check gcloud is installed and on the $PATH.
if ! which gcloud > /dev/null 2>&1; then
    log_error "gcloud is not installed or not on PATH."
fi

# If GCP project ID is not passed in as command line arguments. Check gcloud config for project ID.
[[ -z "${PROJECT_ID}" ]] && get_project

# Check if the project is google-internal. If so, update domain name accordingly.
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if [[ "${PROJECT_ID}" == "google.com:"* ]]; then
    SA_EMAIL="${SA_NAME}@${PROJECT_ID#"google.com:"}.google.com.iam.gserviceaccount.com"
fi

DOWNLOAD_KEY_FILE="y"

check_and_create_service_account "${SA_NAME}" "${SA_EMAIL}" ; RET=$?
if [[ ${RET} -ne 0 ]]; then
    log_info "The service account might have keys associated with it. It is recommended to use existing keys.\n" \
        "Press: y to generate new keys.(this does not de-activate existing keys)\n" \
        "Press: n to skip generating new keys."
    read -r DOWNLOAD_KEY_FILE
fi

[[ "${DOWNLOAD_KEY_FILE}" == "y" ]] && download_keys "${SA_NAME}" "${SA_EMAIL}" "${OUTPUT_DIR}" "${PROJECT_ID}"

bind_policy "${SA_EMAIL}" "${COMP}"