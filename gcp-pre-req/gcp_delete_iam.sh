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
    $(basename "$0") [--help or -h] <prefix>

Description:
    Checks if resource exists (returns yes or no)

Arguments:
    prefix:   prefix for your assets
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage
if [[ (${1:-x} == "--help") || ${1:-x} == "-h" ]]; then
    display_usage
    exit 0
fi

# Check the numbers of arguments
if [ $# -lt 1 ]; then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [ $# -gt 1 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

prefix=$1
project=$(gcloud config get-value project)

log_sa=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-log-sa'") | .email')
datalake_admin_sa=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-dladm-sa'") | .email')
ranger_audit_sa=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-rgraud-sa'") | .email')
idbroker_sa=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-idb-sa'") | .email')
log_role=$(gcloud iam roles list --format json --project ${project} | jq -r '.[] | select(.title=="'${prefix}'-log-role") | .name')
if [[ ${#log_sa} -gt 0 ]]
then
    gcloud iam service-accounts delete $log_sa --quiet
fi

if [[ ${#datalake_admin_sa} -gt 0 ]]
then
    gcloud iam service-accounts delete $datalake_admin_sa --quiet
fi

if [[ ${#ranger_audit_sa} -gt 0 ]]
then
    gcloud iam service-accounts delete $ranger_audit_sa --quiet
fi

if [[ ${#idbroker_sa} -gt 0 ]]
then
    gcloud iam service-accounts delete $idbroker_sa --quiet
fi


if [[ ${#log_role} -gt 0 ]]
then
    role_id=$(echo $log_role | awk -F  "/" '{print $NF}')

    gcloud iam roles delete $role_id --project ${project} --quiet
fi
