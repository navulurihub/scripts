#!/bin/bash

set -e

SKIP_CERT_CHECK="false"
ENABLE_VOLUME_STORAGE="true"
HOSTNAME_CHECK_API="true"
CONNECTION_NAME=""
CLUSTER_NAME=$CLUSTER
GROUP_NAME=""
NETWORK_ZONE=""
API_TOKEN=""
PAAS_TOKEN=""
CLUSTER_NAME_REGEX="^[-_a-zA-Z0-9][-_\.a-zA-Z0-9]*$"
CLUSTER_NAME_LENGTH=256
MASTER_TOKEN=""
ENV_PATH=./deploy/notprod
ENV_TYPE="np"

# List versions
echo "[+]  Listing files"
ls -la
echo "[+] Listing the kustomize version"
kustomize version
echo "[+] Listing the kubectl version"
kubectl version

while [ $# -gt 0 ]; do
  case "$1" in
  --master-token)
    MASTER_TOKEN="$2"
    shift 2
    ;;
  --cluster-name)
    CLUSTER_NAME="$2"
    shift 2
    ;;
  *)
    echo "Warning: skipping unsupported option: $1"
    shift
    ;;
  esac
done

if [[ $CLUSTER_NAME == *"-prod"* ]]; then
  ENV_PATH=./deploy/prod
	echo $ENV_PATH
  ENV_TYPE="prod"
fi
echo "ENV_PATH is set to ${ENV_PATH}"
source ${ENV_PATH}/config.sh

# Get K8s Cluster svc endpoint for kubemon connection
K8S_CLUSTER_IP=$(kubectl get svc -n default | grep kubernetes | awk -F' ' '{print $3}')
if [ -z "$K8S_CLUSTER_IP" ]; then
  echo "[ERROR] Not able to get K8S_CLUSTER_IP!"
  exit 1
fi
K8S_ENDPOINT="https://${K8S_CLUSTER_IP}"

if [ -n "$CLUSTER_NAME" ]; then
  if ! echo "$CLUSTER_NAME" | grep -Eq "$CLUSTER_NAME_REGEX"; then
    echo "Error: cluster name \"$CLUSTER_NAME\" does not match regex: \"$CLUSTER_NAME_REGEX\""
    exit 1
  fi

  if [ "${#CLUSTER_NAME}" -ge $CLUSTER_NAME_LENGTH ]; then
    echo "Error: cluster name too long: ${#CLUSTER_NAME} >= $CLUSTER_NAME_LENGTH"
    exit 1
  fi
  CONNECTION_NAME="$CLUSTER_NAME"
else
  CONNECTION_NAME="$(echo "${K8S_ENDPOINT}" | awk -F[/:] '{print $4}')"
fi

# Define the names to use for OneAgent network zone and ActiveGate group from the cluster name if it exists
if [ -z "$CLUSTER_NAME" ]; then
  GROUP_NAME="Default"
else
  GROUP_NAME="${CLUSTER_NAME}"
fi
NETWORK_ZONE="$(echo ${GROUP_NAME} | tr '[:upper:]' '[:lower:]')"

set -u

deleteNamespace() {
  echo "🐯 Checking environment type..."
  if [[ "$CLUSTER_NAME" == *"dev"* ]] || [[ "$CLUSTER_NAME" == *"platint"* ]] ; then
    echo "🐯 $CLUSTER_NAME is DEV or Platint env, dynatrace needs to be removed ....."
    echo "🐯 Checking Dynatrace Namespace is existing....."

    if kubectl get ns dynatrace >/dev/null 2>&1 ; then
      echo "🐯 Cluster $CLUSTER_NAME has dynatrace namespace"
    
      echo "🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨"
      echo
      echo "WARNING: Deleting Dynatrace namespace for $CLUSTER_NAME"
      echo
      echo "🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨"
      echo
      kubectl delete -f ./deploy/base/namespace.yaml
      echo "🐯Dynatrace resource and namespace on $CLUSTER_NAME has been deleted"
    else
      echo "🐯Cluster $CLUSTER_NAME does not have dynatrace namespace"
    fi

    exit 0

  fi
}

checkIfNSExists() {
#  if kubectl get ns dynatrace >/dev/null 2>&1 && kubectl get namespace/dynatrace -L istio-injection | grep enabled >/dev/null 2>&1; then
#    echo "Istio is enabled. So deleting the namespace and create with Istio disabled"
#    kubectl delete -f ./deploy/base/namespace.yaml
#  fi

# istio is not enabled in forgeds and ingress clusters
  if [[ "$CLUSTER_NAME" == *"forgeds"* ]] || [[ "$CLUSTER_NAME" == *"ingress"* ]] ; then
    echo "Disabling namespace istio injection for $CLUSTER_NAME"
    sed -i 's/istio-injection: enabled/istio-injection: disabled/g' ./deploy/base/namespace.yaml
  fi
  kubectl apply -f ./deploy/base/namespace.yaml
}

applyDynatraceOperatorWithCR() {
	kubectl kustomize ./deploy/projects/${CLUSTER_NAME} --reorder none >> kustomizebuild.yaml
	echo "Separate to 2 files kubernetes.yaml and cr.yaml"
	./deploy/split-cryaml.sh kustomizebuild.yaml

	echo "Run kubernetes.yaml "
	kubectl apply -f kubernetes.yaml

  count=1
	until [[ $(kubectl -n dynatrace get pods -l internal.dynatrace.com/component=webhook -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') = "True True" ]]
	do
	  echo "$count - Wait for webhook to become available" && sleep 10;
	  ((count+=1))
	  if [ $count -gt 15 ]; then
	      break;
	  fi
	done

	echo "Apply the full one with cr.yaml"
	kubectl apply -f kustomizebuild.yaml
#	kubectl kustomize ./deploy/projects/${CLUSTER_NAME} | kubectl apply -f -

	rm ./kubernetes.yaml
	rm ./kustomizebuild.yaml

}

addK8sConfiguration() {
  printf "\nCheck if cluster already exists in dynatrace...\n"
  if [ -z "$API_TOKEN" ]; then
    API_TOKEN="$(kubectl get secret dynatoken -o jsonpath='{.data.apiToken}' -n dynatrace | base64 --decode)"
  fi
  response=$(apiRequest "GET" "/config/v1/kubernetes/credentials" ${API_TOKEN} "")
  DYNA_CONFIG_API_ID=$(echo $response |jq -r --arg CLUSTER_NAME "$CLUSTER_NAME" '.values  | .[] | select(.name==$CLUSTER_NAME) | .id')

  printf "\nAdding K8s config to dynatrace...\n"
  K8S_SECRET_NAME="$(for token in $(kubectl get sa dynatrace-kubernetes-monitoring -o jsonpath='{.secrets[*].name}' -n dynatrace); do echo "$token"; done | grep -F token)"
  if [ -z "$K8S_SECRET_NAME" ]; then
    echo "Error: failed to get kubernetes-monitoring secret!"
    exit 1
  fi

  K8S_BEARER="$(kubectl get secret "${K8S_SECRET_NAME}" -o jsonpath='{.data.token}' -n dynatrace | base64 --decode)"
  if [ -z "$K8S_BEARER" ]; then
    echo "Error: failed to get bearer token!"
    exit 1
  fi

  if "$SKIP_CERT_CHECK" = "true"; then
    CERT_CHECK_API="false"
  else
    CERT_CHECK_API="true"
  fi

  if [ -z "$DYNA_CONFIG_API_ID" ]; then
    json="$(
      cat <<EOF
{
  "label": "${CLUSTER_NAME}",
  "endpointUrl": "${K8S_ENDPOINT}",
  "eventsFieldSelectors": [
    {
      "label": "Node events",
      "fieldSelector": "involvedObject.kind=Node",
      "active": true
    }
  ],
  "workloadIntegrationEnabled": true,
  "eventsIntegrationEnabled": true,
  "eventAnalysisAndAlertingEnabled": true,
  "prometheusExportersIntegrationEnabled": false,
  "davisEventsIntegrationEnabled": true,
  "authToken": "${K8S_BEARER}",
  "active": true,
  "certificateCheckEnabled": "${CERT_CHECK_API}",
  "hostnameVerificationEnabled": "${HOSTNAME_CHECK_API}"
}
EOF
    )"
  else
    json="$(
      cat <<EOF
{
  "id": "${DYNA_CONFIG_API_ID}",
  "label": "${CLUSTER_NAME}",
  "endpointUrl": "${K8S_ENDPOINT}",
  "eventsFieldSelectors": [
    {
      "label": "Node events",
      "fieldSelector": "involvedObject.kind=Node",
      "active": true
    }
  ],
  "workloadIntegrationEnabled": true,
  "eventsIntegrationEnabled": true,
  "eventAnalysisAndAlertingEnabled": true,
  "prometheusExportersIntegrationEnabled": false,
  "davisEventsIntegrationEnabled": true,
  "activeGateGroup": "${CLUSTER_NAME}",
  "authToken": "${K8S_BEARER}",
  "active": true,
  "certificateCheckEnabled": "${CERT_CHECK_API}",
  "hostnameVerificationEnabled": "${HOSTNAME_CHECK_API}"
}
EOF
    )"
  fi

  if [ -z "$DYNA_CONFIG_API_ID" ]; then
    response=$(apiRequest "POST" "/config/v1/kubernetes/credentials" ${API_TOKEN} "${json}")
  else
    echo "Cluster already exists in Dynatrace, hence updating it."
    response=$(apiRequest "PUT" "/config/v1/kubernetes/credentials/${DYNA_CONFIG_API_ID}" ${API_TOKEN} "${json}")
  fi

  if echo "$response" | grep -Fq "${CONNECTION_NAME}"; then
    echo "Kubernetes monitoring successfully setup."
  elif [[ ! -z "$DYNA_CONFIG_API_ID" && -z $response ]]; then
    echo "Kubernetes monitoring successfully updated."
  else
    echo "Error adding Kubernetes cluster to Dynatrace: $response"
  fi
}

getMasterToken() {
	if [ -z "$MASTER_TOKEN" ]; then
		MASTER_TOKEN=$(gcloud secrets versions access projects/${PROJECT_ID}/secrets/anzx-dynatrace-master-token/versions/${MASTER_TOKEN_VERSION})
	fi
	if [ -z "$MASTER_TOKEN" ]; then
		echo "Error: failed to get MASTER_TOKEN!"
		exit 1
	fi
	jsonAPI="{\"token\": \"${MASTER_TOKEN}\"}"

  responseAPI=$(apiRequest "POST" "/v1/tokens/lookup" ${MASTER_TOKEN} "${jsonAPI}")

  if echo "$responseAPI" | grep -Fq "Authentication failed"; then
    echo "Error: MASTER_TOKEN authentication failed!"
    exit 1
  fi
  if ! echo "$responseAPI" | grep -Fq "TenantTokenManagement"; then
    echo "Error: MASTER_TOKEN does not have TenantTokenManagement permission!"
    exit 1
  fi
}

generateTokens() {
  #userId will be inherited from master token owner
  jsonAPI="$(
    cat <<EOF
{
  "name": "${CLUSTER_NAME} - API token",
  "revoked": false,
  "scopes": [
    "DataExport",
    "ReadConfig",
    "WriteConfig",
    "activeGateTokenManagement.create",
    "activeGateTokenManagement.write",
    "entities.read",
    "settings.write",
    "settings.read"
  ],
  "personalAccessToken": false
}
EOF
  )"

  jsonPaaS="$(
    cat <<EOF
{
  "name": "${CLUSTER_NAME} - PaaS Token",
  "revoked": false,
  "scopes": [
    "InstallerDownload",
    "SupportAlert"
  ],
  "personalAccessToken": false
}
EOF
  )"

	responseAPI=$(apiRequest "POST" "/v1/tokens" ${MASTER_TOKEN} "${jsonAPI}")

	if ! echo "$responseAPI" | grep -Fq '"token":'; then
		echo "Error: creating API token failed."
		exit 1
	fi

	API_TOKEN=$(echo "${responseAPI}" | grep -o '"token": *"[^"]*' | grep -o '[^"]*$')

	responsePaaS=$(apiRequest "POST" "/v1/tokens" ${MASTER_TOKEN} "${jsonPaaS}")

	if ! echo "$responsePaaS" | grep -Fq '"token":"'; then
		echo "Error: creating PaaS token failed."
		exit 1
	fi

	PAAS_TOKEN=$(echo "${responsePaaS}" | grep -o '"token": *"[^"]*' | grep -o '[^"]*$')
}

checkTokenScopes() {
  jsonAPI="{\"token\": \"${API_TOKEN}\"}"
  jsonPaaS="{\"token\": \"${PAAS_TOKEN}\"}"

  responseAPI=$(apiRequest "POST" "/v1/tokens/lookup" ${MASTER_TOKEN} "${jsonAPI}")

  if echo "$responseAPI" | grep -Fq "Authentication failed"; then
    echo "Error: API token authentication failed!"
    exit 1
  fi

  if ! echo "$responseAPI" | grep -Fq "WriteConfig"; then
    echo "Error: API token does not have config write permission!"
    exit 1
  fi

  if ! echo "$responseAPI" | grep -Fq "ReadConfig"; then
    echo "Error: API token does not have config read permission!"
    exit 1
  fi
  
  if echo "$responseAPI" | grep -Fq '"revoked": true'; then
    echo "Error: API token has been revoked!"
    exit 1
  fi

  responsePaaS=$(apiRequest "POST" "/v1/tokens/lookup" ${MASTER_TOKEN} "${jsonPaaS}")

  if echo "$responsePaaS" | grep -Fq "Token does not exist"; then
    echo "Error: PaaS token does not exist!"
    exit 1
  fi
  
  if echo "$responseAPI" | grep -Fq '"revoked": true'; then
    echo "Error: PaaS token has been revoked!"
    exit 1
  fi
}

apiRequest() {
  method=$1
  url=$2
  token=$3
  json=$4

  if "$SKIP_CERT_CHECK" = "true"; then
    curl_command="curl -k"
  else
    curl_command="curl"
  fi

  response="$(${curl_command} -sS -X ${method} "${API_URL}${url}" \
    -H "accept: application/json; charset=utf-8" \
    -H "Authorization: Api-Token ${token}" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "${json}")"

  echo "$response"
}

createTokensIfNotExist() {
	if ! kubectl -n dynatrace get secret dynatoken >/dev/null 2>&1; then
		printf "\nGenerate tokens...\n"
		generateTokens
		printf "\nCheck for token scopes...\n"
		checkTokenScopes

    echo "[+] Creating secret [dynatoken] with API_TOKEN and PAAS_TOKEN.."
		kubectl -n dynatrace create secret generic dynatoken \
      --from-literal="apiToken=${API_TOKEN}" \
      --from-literal="paasToken=${PAAS_TOKEN}"
	fi

}

checkIstioIngressCluster() {
  # Check and delete Istio PeerAuthentication config in Ingress clusters
  if [[ "$CLUSTER_NAME" == *"ingress"* ]]; then
    if kubectl get PeerAuthentication/default -n dynatrace >/dev/null 2>&1; then
      echo "[+]  Deleting Istio PeerAuthentication PERMISSIVE setting for $CLUSTER_NAME"
      kubectl delete PeerAuthentication/default -n dynatrace
    else
      echo "No default Istio PeerAuthentication settings is found in: $CLUSTER_NAME"
    fi
  fi
}

#TODO: This is a migration step and can be deleted once all clusters are migrated to Dynatrace Operator
deleteOneAgentInPlatformApm() {
  if kubectl get deployment dynatrace-oneagent-operator -n platform-apm >/dev/null 2>&1; then
    echo "[+] Deleting current oneagent-operator "
    kubectl delete deployment dynatrace-oneagent-operator -n platform-apm
  fi
  if kubectl get ds oneagent -n platform-apm >/dev/null 2>&1; then
    echo "[+] Deleting current oneagent daemonset.."
    kubectl delete ds oneagent -n platform-apm
  fi
}

#TODO: This is a migration step and can be deleted once all clusters are migrated to Dynatrace Operator
deleteActiveGateInPlatformApm() {
  if kubectl get deployment dynatrace-activegate -n platform-apm >/dev/null 2>&1; then
    echo "[+] Deleting current activegate.."
    kubectl delete deployment dynatrace-activegate -n platform-apm
  fi
}

addActiveGateSTS() {
  # Temp solution to install the AG as Operator cannot create it.
  if kubectl get sts dynakube-activegate -n dynatrace  && ! kubectl describe  sts dynakube-activegate -n dynatrace  | grep -iq "v0.9"; then
      # Delete STS if the version is not v0.9
      kubectl delete sts dynakube-activegate -n dynatrace
      echo "[+]  Old ActiveGate Stateful Set has been deleted"
  fi

  echo "[+]  CLUSTER_NAME is [${CLUSTER_NAME}]"
  sed -i 's/CLUSTER_PLACE_HOLDER/'${CLUSTER_NAME}'/g' ./deploy/base/activegate_sts.yaml

  # Update AG version in activegate_sts.yaml
  AG_VERSION=$(grep 'image' $ENV_PATH/cr.yaml | grep 'activegate' | awk -F'activegate:' '{print $2}' | tr -d '"')
  echo "[+]  AG_VERSION is [${AG_VERSION}], ENV_TYPE is [${ENV_TYPE}]"
  sed -i 's/ENV_TYPE_PLACE_HOLDER/'${ENV_TYPE}'/g' ./deploy/base/activegate_sts.yaml
  sed -i 's/AG_VERSION_PLACE_HOLDER/'${AG_VERSION}'/g' ./deploy/base/activegate_sts.yaml

  # Use gov-ops for ForgeDS and Ingress Cluster
  echo "[+]  Updating node selector and tolerations $CLUSTER_NAME"
  if [[ "$CLUSTER_NAME" == *"forgeds"* ]] || [[ "$CLUSTER_NAME" == *"ingress"* ]] ; then
    sed -i 's/NODE_PLACE_HOLDER/gov-ops/g' ./deploy/base/activegate_sts.yaml
  else
    sed -i 's/NODE_PLACE_HOLDER/egress/g' ./deploy/base/activegate_sts.yaml
  fi

  echo "[+]  Deploying to nodepool : "
  grep "nodepool-name" ./deploy/base/activegate_sts.yaml | awk -F':' '{print $2}'

  echo "[+]  Image version in activegate_sts.yaml is: "
  grep "image:" ./deploy/base/activegate_sts.yaml

  echo "[+]  Deploying ActiveGate Stateful Set...."
  kubectl apply -f ./deploy/base/activegate_sts.yaml
}

####### MAIN #######
# This step is to remove Dynatrace from lower env, comment out if need to test on dev
printf "\nChecking if need to delete namespace...\n"
deleteNamespace
# Steps below will be skipped if the Namespace is deleted.

printf "\nCreating Dynatrace namespace...\n"
checkIfNSExists
printf "\nGet Master token from GSM...\n"
getMasterToken
printf "\nCreate API and PAAS tokens if secret does not exist...\n"
createTokensIfNotExist
printf "\nChecking Istio PeerAuthentication mode in Ingress cluster...\n"
checkIstioIngressCluster
printf "\nDelete platform-apm oneagent-operator and oneagent ds if exist...\n"
deleteOneAgentInPlatformApm
printf "\nApplying Dynatrace Operator and DynaKube CustomResource...\n"
applyDynatraceOperatorWithCR
printf "\nAdding cluster to Dynatrace...\n"
addK8sConfiguration
#printf "\nDelete activegate...\n"
#deleteActiveGateInPlatformApm
# printf "\nInstalling ActiveGate STS...\n"
# addActiveGateSTS
printf "\nDynatrace installation completed...\n"
