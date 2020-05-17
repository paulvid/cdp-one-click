#!/bin/bash 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <prefix> <definition> <workspace_name> <cloud_provider> <enable_workspace>[--help or -h]

Description:
    Launches a ML workspace based on definition

Arguments:
    prefix:             prefix of your assets
    definition:         ML workspace definition file location
    workspace_name:     name of your workspace
    enable_workspace:   flag to enable workspace with monitoring, governance and model metrics
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 5 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 5 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 


#Variables
sleep_duration=1

prefix=${1}
def_file=${2}
workspace_name=${3}
cloud_provider=${4}
env_name=${prefix}-cdp-env
enable_workspace=${5}
owner=$(cdp iam get-user | jq -r .user.email)

#Parse and replace variables in workspace template


if [[ ${cloud_provider} == "aws" ]]
then

    if [[ ${enable_workspace} == "yes" ]]
    then
        # Create ML Workspace
        cdp ml create-workspace \
        --no-disable-tls \
        --environment-name ${env_name} \
        --use-public-load-balancer \
        --workspace-name ${workspace_name} \
        --enable-monitoring \
        --enable-governance \
        --enable-model-metrics \
        --provision-k8s-request file://$def_file
    else 
        cdp ml create-workspace \
        --no-disable-tls \
        --environment-name ${env_name} \
        --use-public-load-balancer \
        --workspace-name ${workspace_name} \
        --provision-k8s-request file://$def_file
    fi
fi


if [[ ${cloud_provider} == "az" ]]
then
    echo "not supported"  >&2
    exit 1
fi

#Grant access to workspace
env_crn=$(cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.crn)


#Check if group already has access
hasMLAdmin="false"
hasMLUser="false"
for item in $(cdp iam list-group-assigned-resource-roles --group-name cdp_${prefix}-cdp-env | jq -r .resourceAssignments[].resourceRoleCrn); do
    if [ $item == "crn:altus:iam:us-west-1:altus:resourceRole:MLAdmin" ]
    then
        hasMLAdmin="true"
    fi
    if [ "$item" == "crn:altus:iam:us-west-1:altus:resourceRole:MLUser" ]
    then
        hasMLUser="true"
    fi
done

    
if [[ $hasMLAdmin == "false" ]]
then
    cdp iam assign-group-resource-role \
        --group-name cdp_${prefix}-cdp-env \
        --resource-role "crn:altus:iam:us-west-1:altus:resourceRole:MLAdmin" \
        --resource-crn $env_crn
fi
sleep $sleep_duration

if [[ $hasMLUser == "false" ]]
then
    cdp iam assign-group-resource-role \
        --group-name cdp_${prefix}-cdp-env \
        --resource-role "crn:altus:iam:us-west-1:altus:resourceRole:MLUser" \
        --resource-crn $env_crn
fi
sleep $sleep_duration