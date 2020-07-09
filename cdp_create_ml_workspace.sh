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
sleep_duration=2

prefix=${1}
def_file=${2}
workspace_name=${3}
cloud_provider=${4}
env_name=${prefix}-cdp-env
enable_workspace=${5}
owner=$(cdp iam get-user | jq -r .user.email)

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

    # 1. Creating netapp
    vnet=$(cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.network.azure.networkId)
    rg=$(cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.network.azure.resourceGroupName)
    free_subnet=""

    # 1.1. Finding available subnet
    for subnet in $(az network vnet show --resource-group ${rg} --name ${vnet}  | jq -r .subnets[].name)
    do 
        
        ip_config=$(az network vnet subnet show --resource-group ${rg} --vnet-name ${vnet} --name ${subnet} | jq -r .ipConfigurations | wc -l)
        if [[ ${ip_config} -eq 1 ]] 
        then
            free_subnet=${subnet}
            break
        fi
    done
    
    if [[ ${#free_subnet} -eq 0 ]] 
    then
        echo "No free subnet found fo vnet ${vnet} in resource group ${rg}!" >&2
        exit 1
    fi


    # 1.2. Adding Netapp delegation for this subnet
    az network vnet subnet update --resource-group ${rg} --vnet-name ${vnet} --name ${free_subnet} --remove serviceEndpoints
    sleep $sleep_duration
    az network vnet subnet update --resource-group ${rg} --vnet-name ${vnet} --name ${free_subnet} --delegations Microsoft.Netapp/volumes
    sleep $sleep_duration

    # 1.3. Creating netapp
    az netappfiles account create --resource-group ${rg} --name ${prefix}-netapp-acct
    sleep $sleep_duration
    az netappfiles pool create --resource-group ${rg} --account-name ${prefix}-netapp-acct --pool-name ${prefix}-pool --service-level Standard --size 4
    sleep $sleep_duration
    az netappfiles volume create --resource-group ${rg} --account-name ${prefix}-netapp-acct --pool-name ${prefix}-pool --volume-name ${prefix}-volume --file-path "${prefix}-path" --usage-threshold 2000 --vnet ${vnet} --subnet ${free_subnet}
    sleep $sleep_duration
    start_ip=$(az netappfiles volume show --resource-group ${rg} --account-name ${prefix}-netapp-acct --pool-name ${prefix}-pool --volume-name ${prefix}-volume | jq -r .mountTargets[0].startIp)
   

    # 2. Creating workspace
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
        --existing-nfs "$start_ip:/${prefix}-path" \
        --provision-k8s-request file://$def_file
    else 
        cdp ml create-workspace \
        --no-disable-tls \
        --environment-name ${env_name} \
        --use-public-load-balancer \
        --workspace-name ${workspace_name} \
        --existing-nfs "$start_ip:/${prefix}-path" \
        --provision-k8s-request file://$def_file
    fi
  
fi

