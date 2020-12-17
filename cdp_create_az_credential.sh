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
    $(basename "$0") [--help or -h] <credential_name> <app_id> <app_secret>

Description:
    Launches a CDP environment

Arguments:
    credential_name: name of your credential
    app_id:          id of your credential app
    app_secret:      password of your credential app
    --help or -h:    displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 3 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 3 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

credential_name=$1
app_id=$2
app_secret=$3



details=$(az account list |jq '.[] | select(.isDefault==true) |{"name": .name, "subscriptionId": .id, "tenantId": .tenantId, "state": .state}')
subscriptionId=$(echo $details | jq -r .subscriptionId)
tenantId=$(echo $details | jq -r .tenantId)

cdp environments create-azure-credential --credential-name ${credential_name} --subscription-id ${subscriptionId} --tenant-id ${tenantId} --app-based applicationId=${app_id},secretKey=${app_secret}