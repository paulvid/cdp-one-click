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

# Getting Subscription details
details=$(az account list |jq '.[] | select(.isDefault==true) |{"name": .name, "subscriptionId": .id, "tenantId": .tenantId, "state": .state}')
subscriptionId=$(echo $details | jq -r .subscriptionId)
tenantId=$(echo $details | jq -r .tenantId)

# Creating application
result=$(az ad sp create-for-rbac --name http://$app_name --role Contributor --scopes /subscriptions/${subscriptionId})


echo $result
