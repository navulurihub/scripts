#!/usr/bin/env bash
set -euo pipefail

declare workflow

# Define the various stages available to be to skipped. If we need more please add here.
declare -a CLUSTERS=(
  "APPS"
  "SERVICES"
)

# Take the target that you wish to not skip from harness as a wf variable
declare TARGET="${workflow.variables.pipeline_target}"

# If the target var is not set run the pipeline as normal by setting the skip bool to be false.
if [ -n "${TARGET}" ]
 then
   declare SKIP_BOOL=true
 else
   declare SKIP_BOOL=false
fi

# iterate over the CLUSTERS from the above array and set the cluster to the skip bool above.
for cluster in "${CLUSTERS[@]}"
  do
    declare -x SKIP_"${cluster}"=${SKIP_BOOL}
    echo "SKIP_${cluster} is set to ${SKIP_BOOL}"
done
# Always set the target to false so that you dont skip it.
declare -x "SKIP_${TARGET}"=false
echo "SKIP_${TARGET} is set to false"