#!/bin/bash
set -o nounset

display_usage() {
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <resource>

Description:
    Checks if resource exists (returns yes or no)

Arguments:
    prefix:   prefix for your assets
    resource: type of resource to check (in: rg, network, storage, iam) 
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage
if [[ (${1:-x} == "--help") || ${1:-x} == "-h" ]]; then
    display_usage
    exit 0
fi

# Check the numbers of arguments
if [ $# -lt 2 ]; then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [ $# -gt 2 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

prefix=$1
resource=$2
response="no"

if [[ "$resource" != "rg" && "$resource" != "network" && "$resource" != "storage" && "$resource" != "iam" ]]; then
    echo "$resource is not a recognized resource type!" >&2
    display_usage
    exit 1
fi

if [[ "$resource" == "rg" ]]; then
    rg_state=$(az group show --name $prefix-cdp-rg 2>/dev/null | jq -r .properties.provisioningState)
    if [[ "$rg_state" == "Succeeded" ]]; then
        response="yes"
    fi

fi

if [[ "$resource" == "storage" ]]; then
    storage_state=$(az storage account show -g $prefix-cdp-rg -n "${prefix//-}"cdpsa 2>/dev/null | jq -r .provisioningState)
    if [[ "$storage_state" == "Succeeded" ]]; then
        response="yes"
    fi

fi

if [[ "$resource" == "network" ]]; then
    network_state=$(az network vnet show -g $prefix-cdp-rg -n $prefix-cdp-vnet 2>/dev/null | jq -r .provisioningState)
    if [[ "$network_state" == "Succeeded" ]]; then
        response="yes"
    fi

fi

if [[ "$resource" == "iam" ]]; then

    # 1. Checking policies
    log_role_name="loggerIdentity"
    log_role_exists="no"
    ranger_role_name="rangerIdentity"
    ranger_role_exists="no"
    idbroker_role_name="assumerIdentity"
    idbroker_role_exists="no"
    dl_admin_role_name="adminIdentity"
    dl_admin_role_exists="no"

    if [[ "$log_role_name" == "$(az identity show -g $prefix-cdp-rg -n $log_role_name 2>/dev/null | jq -r .name)" ]]; then
        log_role_exists="yes"
    fi

    if [[ "$ranger_role_name" == "$(az identity show -g $prefix-cdp-rg -n $ranger_role_name 2>/dev/null | jq -r .name)" ]]; then
        ranger_role_exists="yes"
    fi

    if [[ "$idbroker_role_name" == "$(az identity show -g $prefix-cdp-rg -n $idbroker_role_name 2>/dev/null | jq -r .name)" ]]; then
        idbroker_role_exists="yes"
    fi

    if [[ "$dl_admin_role_name" == "$(az identity show -g $prefix-cdp-rg -n $dl_admin_role_name 2>/dev/null | jq -r .name)" ]]; then
        dl_admin_role_exists="yes"
    fi

    if [[ ("$log_role_exists" == "yes") && (\
        "$ranger_role_exists" == "yes") && (\
        "$idbroker_role_exists" == "yes") && (\
        "$dl_admin_role_exists" == "yes") ]]; then
        response="yes"
    fi

fi

echo $response
