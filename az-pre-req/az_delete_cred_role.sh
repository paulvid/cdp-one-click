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

delete_role_assignments() {
    role_name=$1
    assignment_list=$(az role assignment list --role ${role_name} | jq -r .[].id)
    for id in $(echo $assignment_list)
    do
        az role assignment delete --ids "$id"
        sleep 2
    done


}


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

role_name="$1-cred-role"




roleList=$(az role definition list --name "$role_name")
if [[ ${roleList} == "[]" ]]
then
    echo "Role non existent! Nothing to do"
else
   delete_role_assignments  ${role_name}
   sleep 3
   az role definition delete --name "${role_name}"
fi
