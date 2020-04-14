#!/bin/bash 
set -o nounset

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

resource_group_name="$1-cdp-rg"
location=$2


result=$(az group exists -o json -g "$resource_group_name")
if [[ "$result" == "false"  ]]; then
   az group create --name ${resource_group_name} --location "${location}"
fi