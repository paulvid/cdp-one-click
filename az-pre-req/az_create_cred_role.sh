#!/bin/bash 
set -o nounset

BASE_DIR=$(cd $(dirname $0); pwd -L)

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> 

Description:
    Creates Azure resource group

Arguments:
    prefix:         prefix for your app
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
role_name="${prefix}-cred-role"
app_name="${prefix}-cred-app"
details=$(az account list|jq '.[0]|{"name": .name, "subscriptionId": .id, "tenantId": .tenantId, "state": .state}')
subscriptionId=$(echo $details | jq -r .subscriptionId)

# Creating role
cat ${BASE_DIR}/az_cred_role.json | sed s/{subscriptionId}/"${subscriptionId}"/g | sed s/{name}/"${role_name}"/g  > ${BASE_DIR}/${prefix}_tmp
az role definition create --role-definition ${BASE_DIR}/${prefix}_tmp
rm ${BASE_DIR}/${prefix}_tmp
sleep 60

# Assigning roles to 
appId=$(az ad app list --display-name $app_name | jq -r .[].appId)



az role assignment create --assignee ${appId} --role Contributor --scope /subscriptions/${subscriptionId}
sleep 60

az role assignment create --assignee ${appId} --role ${role_name} --scope /subscriptions/${subscriptionId}