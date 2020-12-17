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
    Deletes Azure resource group

Arguments:
    prefix:         prefix for your resource group (name <prefix>-cdp-rg)
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


# Listing all resources
rg_list=$( az group list | jq -r .[].id | awk -F '/' '{print $5}')

for resource_group_name in $(echo $rg_list)
do 

    if [[ $resource_group_name == $prefix-* ]]
    then
        az group delete --name ${resource_group_name} --yes
    fi
done



