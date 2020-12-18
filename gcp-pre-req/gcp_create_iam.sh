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

# Logs
deleted=$(gcloud iam roles list --project ${project} --show-deleted --format json | jq -r '.[] | select(.title=="'${prefix}'-log-role") | .deleted')

if [[ ${deleted} == "true" ]]
then
    log_role=$(gcloud iam roles list --format json --project ${project} --show-deleted | jq -r '.[] | select(.title=="'${prefix}'-log-role") | .name')
    role_id=$(echo $log_role | awk -F  "/" '{print $NF}')
    gcloud iam roles undelete ${role_id} --project=${project}
else
    gcloud iam roles create ${prefix}_log_role --project=${project} --title=${prefix}-log-role --description=${prefix}-log-role  --permissions=storage.buckets.get,storage.objects.create --stage=ALPHA
fi
gcloud iam service-accounts create ${prefix}-log-sa --description="${prefix}-log-sa" --display-name="${prefix}-log-sa"
gcloud projects add-iam-policy-binding ${project} --member="serviceAccount:${prefix}-log-sa@${project}.iam.gserviceaccount.com" --role="projects/${project}/roles/${prefix}_log_role" --condition='expression=resource.name == "'${prefix}'-cdp-logs",title='${prefix}'-cdp-logs'
gsutil iam ch serviceAccount:${prefix}-log-sa@${project}.iam.gserviceaccount.com:admin gs://${prefix}-cdp-logs



# DL Admin

gcloud iam service-accounts create ${prefix}-datalake-admin-sa --description="${prefix}-datalake-admin-sa" --display-name="${prefix}-datalake-admin-sa"
gcloud projects add-iam-policy-binding ${project} --member="serviceAccount:${prefix}-datalake-admin-sa@${project}.iam.gserviceaccount.com" --role="roles/storage.admin" --condition='expression=resource.name == "'${prefix}'-cdp-data",title='${prefix}'-datalake-admin'
gcloud projects add-iam-policy-binding ${project} --member="serviceAccount:${prefix}-datalake-admin-sa@${project}.iam.gserviceaccount.com" --role="roles/storage.admin" --condition='expression=resource.name == "//storage.googleapis.com/projects/_/buckets/'${prefix}'-cdp-data",title=full-'${prefix}'-datalake-admin'
gsutil iam ch serviceAccount:${prefix}-datalake-admin-sa@${project}.iam.gserviceaccount.com:admin gs://${prefix}-cdp-data


# Ranger

gcloud iam service-accounts create ${prefix}-ranger-audit-sa --description="${prefix}-ranger-audit-sa" --display-name="${prefix}-ranger-audit-sa"
gcloud projects add-iam-policy-binding ${project} --member="serviceAccount:${prefix}-ranger-audit-sa@${project}.iam.gserviceaccount.com" --role="roles/storage.objectAdmin" --condition='expression=resource.name == "'${prefix}'-cdp-data",title='${prefix}'-ranger-audit'
gcloud projects add-iam-policy-binding ${project} --member="serviceAccount:${prefix}-ranger-audit-sa@${project}.iam.gserviceaccount.com" --role="roles/storage.objectAdmin" --condition='expression=resource.name == "//storage.googleapis.com/projects/_/buckets/'${prefix}'-cdp-data",title=full-'${prefix}'-ranger-audit'
gsutil iam ch serviceAccount:${prefix}-ranger-audit-sa@${project}.iam.gserviceaccount.com:admin gs://${prefix}-cdp-data

#IDbroker

gcloud iam service-accounts create ${prefix}-idbroker-sa --description="${prefix}-idbroker-sa" --display-name="${prefix}-idbroker-sa"
gcloud projects add-iam-policy-binding ${project} --member="serviceAccount:${prefix}-idbroker-sa@${project}.iam.gserviceaccount.com" --role="roles/iam.workloadIdentityUser" --condition='expression=resource.name.startsWith("'${prefix}'"),title='${prefix}'-idbroker'
gcloud projects add-iam-policy-binding ${project} --member="serviceAccount:${prefix}-idbroker-sa@${project}.iam.gserviceaccount.com" --role="roles/iam.serviceAccountUser" --condition=None
gcloud projects add-iam-policy-binding ${project} --member="serviceAccount:${prefix}-idbroker-sa@${project}.iam.gserviceaccount.com" --role="roles/iam.serviceAccountTokenCreator" --condition=None