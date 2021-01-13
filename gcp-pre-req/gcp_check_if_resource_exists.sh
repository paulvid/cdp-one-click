#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi
set -o nounset

display_usage() {
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <resource>

Description:
    Checks if resource exists (returns yes or no)

Arguments:
    prefix:   prefix for your assets
    resource: type of resource to check (in: rg, network, storage, iam, netapp) 
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage
if [[ (${1:-x} == "--help") || ${1:-x} == "-h" ]]; then
    display_usage
    exit 0
fi

# Check the numbers of arguments
if [ $# -lt 2 ]; then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [ $# -gt 2 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

prefix=$1
resource=$2
response="no"

if [[ "$resource" != "buckets" && "$resource" != "iam" && "$resource" != "network"  ]]; then
    echo "$resource is not a recognized resource type!" >&2
    display_usage
    exit 1
fi

if [[ "$resource" == "network" ]]; then
  network_name="${prefix}-cdp-network"
  network=$(gcloud compute networks list --format json | jq -r '.[] | select(.name=="'${network_name}'") | .name')
  if [ ${#network} -gt 0 ]
  then
    response="yes"
  fi

fi

if [[ "$resource" == "buckets" ]]; then
  log_bucket="${prefix}-cdp-logs"
  data_bucket="${prefix}-cdp-data"
  log=$(gsutil ls gs:// | grep $log_bucket)
  data=$(gsutil ls gs:// | grep $data_bucket)
  if [ ${#log} -gt 1 ] && [ ${#data} -gt 1 ]
  then
    response="yes"
  fi

fi

if [[ "$resource" == "iam" ]]; then

  log_sa=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-log-sa'") | .email')
  datalake_admin_sa=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-dladm-sa'") | .email')
  ranger_audit_sa=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-rgraud-sa'") | .email')
  idbroker_sa=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-idb-sa'") | .email')

  if [ ${#log_sa} -gt 1 ] && [ ${#datalake_admin_sa} -gt 1 ] && [ ${#ranger_audit_sa} -gt 1 ] && [ ${#idbroker_sa} -gt 1 ]
  then
    response="yes"
  fi

fi


echo $response
