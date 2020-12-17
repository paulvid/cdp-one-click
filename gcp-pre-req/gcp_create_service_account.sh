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
    Deletes Azure resource group

Arguments:
    prefix:         prefix for your service account (name <prefix>-cdp-cred-sa)
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 1 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 1 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

prefix=$1

SERVICE_ACCOUNT_NAME=${prefix}-cdp-cred-sa
PROJECT_ID=$(gcloud config get-value project)

# Listing all resources

gcloud services enable compute.googleapis.com runtimeconfig.googleapis.com  --quiet

gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name "${prefix}-cdp-cred-sa" --quiet


gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/compute.instanceAdmin.v1 --quiet --no-user-output-enabled --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/compute.networkAdmin --quiet --no-user-output-enabled --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/compute.securityAdmin --quiet --no-user-output-enabled --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/compute.imageUser --quiet --no-user-output-enabled --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/compute.storageAdmin --quiet --no-user-output-enabled --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/runtimeconfig.admin --quiet --no-user-output-enabled --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/cloudkms.admin --quiet --no-user-output-enabled --condition=None

# temp
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/owner --quiet --no-user-output-enabled --condition=None

gcloud iam service-accounts keys create --iam-account=$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com $SERVICE_ACCOUNT_NAME-gcp-cred.json  --quiet






