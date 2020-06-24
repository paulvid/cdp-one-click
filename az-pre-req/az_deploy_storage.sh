#!/bin/bash 
set -o nounset
BASE_DIR=$(cd $(dirname $0); pwd -L)
display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <location>

Description:
    Creates Azure resource group

Arguments:
    prefix:         prefix for your resource group (name <prefix>-cdp-rg)
    location:       region of your resource group
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
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

if [  $# -gt 2 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 
prefix=$1
prefix_no_dash=$(echo $prefix | sed s/-//g)
resource_group_name="$1-cdp-rg"
storage_account_name="$prefix_no_dash""cdpsa"
file_system="data"
location=$2


result=$(az storage account check-name -o json -n "$storage_account_name" | jq -r .nameAvailable | grep "false")
if [[ -z "$result" ]]; then
   az group deployment create \
     --resource-group ${resource_group_name} \
     --template-file "${BASE_DIR}/adls_gen2_deployment.json" \
     --parameters storageAccountName="$storage_account_name" location="$location" filesystem="$file_system" 
fi




