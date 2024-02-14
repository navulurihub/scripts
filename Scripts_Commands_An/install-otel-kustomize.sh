
#!/bin/bash
# ####
# Namespace is managed in PCM repo:
#  https://github.com/anzx/platform-config-management/blob/master/config/namespace/platform-opentelemetry/values.yaml
#

set -eu

NAMESPACE="platform-opentelemetry"

applyK8sManifests() {
	kubectl kustomize ./deploy/projects/"${CLUSTER_NAME}" --reorder none >> kustomizebuild.yaml

	echo "Apply the kustomizebuild.yaml"
	kubectl apply -f kustomizebuild.yaml -n $NAMESPACE

	if [ "$(kubectl -n $NAMESPACE get pods -l app=opentelemetry -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}')" ]; then
	  echo "Restarting deployment to apply latest config map changes" ;
		kubectl rollout restart deployment otel-collector -n $NAMESPACE
	fi
}

####### MAIN #######
printf "\n[+]  Apply K8s Manifests...\n"
applyK8sManifests

printf "\n[+]  Installation completed...\n"