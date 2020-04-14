#!/bin/bash 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <environment_name> <workspace_name>  [--help or -h]

Description:
    Describes an ML workspace.

Arguments:
    environment_name:    name of your environment
    workspace_name:      name of your workspace
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 2 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 2 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 


cdp ml describe-workspace --environment-name ${1} --workspace-name ${2}