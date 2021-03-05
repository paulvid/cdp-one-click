#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <prefix> <scale> (<rds_ha>) [--help or -h]

Description:
    Creates a data lake post environment creation

Arguments:
    prefix:         prefix for your assets
    scale:          scale of the datalake
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
if [  $# -lt 2 ] 
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

if [ $# -eq 3 ] 
then 
    rds_ha=$3
else
    rds_ha=1
fi 

flatten_tags() {
    tags=$1
    flattened_tags=""
    for item in $(echo ${tags} | jq -r '.[] | @base64'); do
        _jq() {
            echo ${item} | base64 --decode | jq -r ${1}
        }
        #echo ${item} | base64 --decode
        key=$(_jq '.key')
        value=$(_jq '.value')
        flattened_tags=$flattened_tags" key=\"$key\",value=\"$value\""
    done
    echo $flattened_tags
}


sleep_duration=1 

# Create groups
owner=$(cdp iam get-user | jq -r .user.email)
SUBSCRIPTION_ID=$(az account show | jq -r .id)
if [ ${rds_ha} -eq 1 ] 
then 
    cdp datalake create-azure-datalake --datalake-name $1-cdp-dl \
        --environment-name $1-cdp-env \
        --cloud-provider-configuration managedIdentity="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/$1-cdp-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/assumerIdentity",storageLocation="abfs://data@${1//-/}cdpsa.dfs.core.windows.net" \
        --scale $2 \
        --tags $(flatten_tags $TAGS) 
else
    cdp datalake create-azure-datalake --datalake-name $1-cdp-dl \
        --environment-name $1-cdp-env \
        --cloud-provider-configuration managedIdentity="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/$1-cdp-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/assumerIdentity",storageLocation="abfs://data@${1//-/}cdpsa.dfs.core.windows.net" \
        --scale $2 \
        --tags $(flatten_tags $TAGS) \
        --database-availability-type NONE
fi
