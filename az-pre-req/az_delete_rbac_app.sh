#!/bin/bash 
set -o nounset

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

app_name="$1-cred-app"


appList=$(az ad app list --display-name "$app_name")
if [[ ${appList} == "[]" ]]
then
    echo "App non existent! Nothing to do."
else
   appId=$(echo $appList | jq -r .[].appId)
   az ad app delete --id ${appId}
fi

