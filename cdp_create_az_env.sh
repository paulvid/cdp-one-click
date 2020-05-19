#!/bin/bash 
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <credential> <region> <key> <sg_cidr>

Description:
    Launches a CDP Azure environment

Arguments:
    prefix:         prefix for your assets
    credentials:    CDP credential name
    region:         region for your env
    key:            name of the Azure key to re-use
    sg_cidr:        CIDR to open in your security group
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 4 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 4 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 

prefix=$1
credential=$2
region=$3
key=$4
sg_cidr=$5

SUBSCRIPTION_ID=$(az account show | jq -r .id)

cdp environments create-azure-environment  --environment-name ${prefix}-cdp-env \
    --credential-name ${credential} \
    --region "${region}" \
    --public-key "${key}" \
    --security-access cidr="$sg_cidr" \
    --log-storage storageLocationBase="abfs://logs@${prefix}cdpsa.dfs.core.windows.net",managedIdentity="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${prefix}-cdp-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/loggerIdentity" \
    --new-network-params networkCidr="10.10.0.0/16" \
    --use-public-ip


