#!/bin/bash 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <prefix> (<rds_ha>) [--help or -h]

Description:
    Creates a data lake post environment creation

Arguments:
    prefix:         prefix for your assets
    rds_ha:         (optional) flag for rds ha (values 0 or 1)
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
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

if [  $# -gt 2 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

if [ $# -eq 2 ] 
then 
    rds_ha=$2
else
    rds_ha=1
fi 

sleep_duration=1 

# Create groups
owner=$(cdp iam get-user | jq -r .user.email)
SUBSCRIPTION_ID=$(az account show | jq -r .id)
if [ ${rds_ha} -eq 1 ] 
then 
    cdp datalake create-azure-datalake --datalake-name $1-cdp-dl \
        --environment-name $1-cdp-env \
        --cloud-provider-configuration managedIdentity="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/$1-cdp-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/assumerIdentity",storageLocation="abfs://data@${1//-/}cdpsa.dfs.core.windows.net" \
        --tags key="enddate",value="${END_DATE}" key="project",value="${PROJECT}" key="deploytool",value="one-click" key="owner",value="${owner}"
else
    cdp datalake create-azure-datalake --datalake-name $1-cdp-dl \
        --environment-name $1-cdp-env \
        --cloud-provider-configuration managedIdentity="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/$1-cdp-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/assumerIdentity",storageLocation="abfs://data@${1//-/}cdpsa.dfs.core.windows.net" \
        --tags key="enddate",value="${END_DATE}" key="project",value="${PROJECT}" key="deploytool",value="one-click" key="owner",value="${owner}" \
        --database-availability-type NONE
fi
