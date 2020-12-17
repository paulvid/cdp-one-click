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
    prefix:         prefix for your service account (name <prefix>-cdp-cred-sa)
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


email=$(gcloud iam service-accounts list --format json | jq -r '.[] | select(.displayName=="'${prefix}-cdp-cred-sa'") | .email')

if [[ ${#email} -gt 0 ]]
then
    gcloud iam service-accounts delete $email --quiet
fi