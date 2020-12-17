#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 


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


# Global vars
cluster_type=$(echo ${def_file} | awk -F "/" '{print $NF}' | awk -F "." '{print $1}') 
cluster_name=${prefix}-${cluster_type}
env_name=${prefix}-cdp-env
dl_name=${prefix}-cdp-dl
# Standard definition
if [[ $(cat ${def_file} | jq -r .definition_type) == "standard" ]]
then
    dl_version=$(cdp datalake describe-datalake --datalake-name $dl_name | jq -r .datalake.clouderaManager.version)
    if [[ ${#dl_version} -lt 1 ]]
    then
        dl_version=$(curl -s https://cloudbreak-imagecatalog.s3.amazonaws.com/v3-prod-cb-image-catalog.json   | jq -r '.images | ."cdh-images" | sort_by(.created) | reverse[] | .version ' | head -1)
    fi

    definition_name=$(cat ${def_file} | jq -r .official_name | sed s/VERSION/${dl_version}/g)

    def_template=$(cdp datahub describe-cluster-definition --cluster-definition-name "${definition_name}" | jq -r .clusterDefinition.workloadTemplate)

    catalog_name="cdp-default"
    id=$(curl -s https://cloudbreak-imagecatalog.s3.amazonaws.com/v3-prod-cb-image-catalog.json | jq -r '.images | ."cdh-images" | sort_by(.created) | reverse[] | select (.version=="'${dl_version}'" and .images.azure?) | .uuid' | head -1)
    
else
# Custom definition
    def_template=$(cat ${def_file})
    id=$(cat ${def_file} | jq -r .image.id)
    catalog_name=$(cat ${def_file} | jq -r .image.catalog)
    
fi
image="id=\"${id}\",catalogName=\"${catalog_name}\""
cluster_template=$(echo ${def_template} | jq -r .cluster.blueprintName)

instance_groups='';
for row in $(echo ${def_template} | jq -r '.instanceGroups[] | @base64'); do
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

image="id=\"${id}\",catalogName=\"${catalog_name}\""

subnet_id=$(cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.network.subnetIds[0])

cdp datahub create-azure-cluster --cluster-name ${cluster_name} \
--environment-name ${env_name} \
--cluster-template-name "${cluster_template}" \
--instance-groups ${instance_groups} \
--subnet-id ${subnet_id} \
--image ${image}


