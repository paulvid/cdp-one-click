#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <base_dir> <prefix> [--help or -h]

Description:
    Creates the appropriate groups for recently create env

Arguments:
    base_dir:       the base directory of the cdp workshop code
    prefix:         prefix for your assets
    --help or -h:   displays this help"

}


generate_post_data()
{
cat<<EOF
[ { "accessorCrn": "${ENVCRN}",
    "role":"${ADMIN_MSI_ID}"
  }
]
EOF
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

sleep_duration=3 

prefix=$2
project=$(gcloud config get-value project)

# Create groups
env_crn=$(cdp environments describe-environment --environment-name $2-cdp-env | jq -r .environment.crn)
user_crn=$(cdp iam get-user | jq -r .user.crn)

env_user_exists=$(cdp iam list-user-assigned-resource-roles | jq '.resourceAssignments[] | select(.resourceCrn=="'$env_crn'" and .resourceRoleCrn=="crn:altus:iam:us-west-1:altus:resourceRole:EnvironmentAdmin")' | wc -l)

if [ $env_user_exists -eq 0 ]
then
    cdp iam assign-user-resource-role  \
        --user $user_crn \
        --resource-role-crn "crn:altus:iam:us-west-1:altus:resourceRole:EnvironmentUser" \
        --resource-crn $env_crn
    sleep $sleep_duration
fi

new_rbac=$(cdp iam list-resource-roles | grep DataHubCreator | wc -l)

if [ $new_rbac -gt 0 ]
then
    dh_creator_exists=$(cdp iam list-user-assigned-resource-roles | jq '.resourceAssignments[] | select(.resourceCrn=="'$env_crn'" and .resourceRoleCrn=="crn:altus:iam:us-west-1:altus:resourceRole:DataHubCreator")' | wc -l)
    if [ $dh_creator_exists -eq 0 ]
    then
        cdp iam assign-user-resource-role  \
            --user $user_crn \
            --resource-role-crn "crn:altus:iam:us-west-1:altus:resourceRole:DataHubCreator" \
            --resource-crn $env_crn
        sleep $sleep_duration
    fi
fi

# Create IDBroker mappings


cdp environments set-id-broker-mappings \
               --environment-name "$2-cdp-env" \
               --baseline-role "${prefix}-ranger-audit-sa@${project}.iam.gserviceaccount.com" \
               --data-access-role "${prefix}-datalake-admin-sa@${project}.iam.gserviceaccount.com" \
               --mappings accessorCrn="$user_crn",role="${prefix}-datalake-admin-sa@${project}.iam.gserviceaccount.com"
