#!/bin/bash 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <prefix> <definition> [--help or -h]

Description:
    Launches a datahub cluster based on definition

Arguments:
    prefix:         prefix of your assets
    definition:     cluster definition file location
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




# Parsing variables
prefix=${1}
def_file=${2}


cluster_type=$(echo ${def_file} | awk -F "/" '{print $NF}' | awk -F "." '{print $1}') 
cluster_name=${prefix}-${cluster_type}
env_name=${prefix}-cdp-env

cluster_template=$(cat ${def_file} | jq -r .cluster.blueprintName)

instance_groups='';
for row in $(cat ${def_file} | jq -r '.instanceGroups[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    node_count=$(_jq '.nodeCount')
    instance_group_name=$(_jq '.name')
    instance_group_type=$(_jq '.type')
    instance_type=$(_jq '.template.instanceType')
    root_volume_size=$(_jq '.template.rootVolume.size')
    volume_size=$(_jq '.template.attachedVolumes[0].size')
    volume_count=$(_jq '.template.attachedVolumes[0].count')
    volume_type=$(_jq '.template.attachedVolumes[0].type')
    recovery_mode=$(_jq '.recoveryMode')
    enable_encryption=$(_jq  '.template.azure.encrypted')
    recipes=''
    for recipe in $(_jq '.recipeNames[]'); do
        recipes=${recipes}${recipe},
    done


    if [ ${#recipes} -gt 0 ]; 
        then recipes="recipeNames="$(echo ${recipes} | rev | cut -c 2- | rev)",";
        else recipes=''
    fi
    instance_groups=$instance_groups" nodeCount=${node_count},instanceGroupName=${instance_group_name},instanceGroupType=${instance_group_type},instanceType=${instance_type},rootVolumeSize=${root_volume_size},attachedVolumeConfiguration=[{volumeSize=${volume_size},volumeCount=${volume_count},volumeType=${volume_type}}],${recipes}recoveryMode=${recovery_mode} " 
done
id=$(cat ${def_file} | jq -r .image.id)
catalog_name=$(cat ${def_file} | jq -r .image.catalog)
image="id=\"${id}\",catalogName=\"${catalog_name}\""

subnet_id=$(cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.network.subnetIds[0])

cdp datahub create-azure-cluster --cluster-name ${cluster_name} \
--environment-name ${env_name} \
--cluster-template-name "${cluster_template}" \
--instance-groups ${instance_groups} \
--subnet-id ${subnet_id} \
--image ${image}


