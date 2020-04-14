#!/bin/bash 
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") credential_name role_arn  [--help or -h] 

Description:
    Launches a CDP environment

Arguments:
    credential_name: name of your credential
    role_arn:        role arn that has cross account policy
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

credential_name=$1
role_arn=$2

cdp environments create-aws-credential --credential-name ${credential_name} --role-arn ${role_arn}