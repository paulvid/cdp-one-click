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
    $(basename "$0") [--help or -h] <credential_name> <cred_json>

Description:
    Launches a CDP environment

Arguments:
    credential_name: name of your credential
    cred_json:       the json file created for your credential
    --help or -h:    displays this help"

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

credential_name=$1
cred_json=$2

# We verify that the key is here

if test -f $cred_json
then
    cdp environments create-gcp-credential --credential-name ${credential_name} --credential-key file://$cred_json
else
    echo "cred_json not found!"  >&2
fi