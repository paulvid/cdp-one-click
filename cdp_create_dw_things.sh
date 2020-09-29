#!/bin/bash
source $(
    cd $(dirname $0)
    pwd -L
)/common.sh

display_usage() {
    echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Creates all CDW listed in your paramater json file (run this script after creating your env + datalake)

Arguments:
    parameter_file: location of your parameter json file (templates can be found in parameters_templates folder)
   "
}

# check whether user had supplied -h or --help . If yes display usage
if [[ ($1 == "--help") || $1 == "-h" ]]; then
    display_usage
    exit 0
fi

# Check the numbers of arguments
if [ $# -lt 1 ]; then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [ $# -gt 1 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

# Parsing arguments
parse_parameters ${1}
env_crn=$(cdp environments describe-environment --environment-name $prefix-cdp-env | jq -r .environment.crn)
# 1. Creating datahub cluster
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating CDP VWs for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""


# 1. Checking if dw cluster is setup
env_crn=$(cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.crn)
cluster_id=$(cdp dw list-clusters | jq -r '.clusters[] | select(.environmentCrn=="'${env_crn}'") | .id')

if [ ${#cluster_id} -gt 0 ]; then
    printf "\r${ALREADY_DONE}  $prefix: CDW cluster already available     "
    echo ""
else

    if [[ ${cloud_provider} == "aws" ]]
    then
        options="publicSubnetIds="
        for subnet_id in $(cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.network.dwxSubnets[].subnetId)
        do
            options=${options}$subnet_id","
        done
        
        aws_options=$(echo $options | sed 's/.$//')
     

        result=$(cdp dw create-cluster --environment-crn ${env_crn} --aws-options $aws_options 2>&1 >/dev/null)
        handle_exception $? $prefix "CDW cluster creation" "$result"

    fi
    
    if [[ ${cloud_provider} == "az" ]]
    then
        options="subnetId="
        for subnet_id in $(cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.network.dwxSubnets[].subnetId)
        do
            options=${options}$subnet_id","
        done
        
        az_options=$options"enableAZ=true"

        result=$(cdp dw create-cluster --environment-crn ${env_crn} --azure-options $az_options 2>&1 >/dev/null)
        handle_exception $? $prefix "CDW cluster creation" "$result"

    fi

    
    
    cluster_id=$(cdp dw list-clusters | jq -r '.clusters[] | select(.environmentCrn=="'${env_crn}'") | .id')

    cluster_status=$(cdp dw describe-cluster --cluster-id ${cluster_id} | jq -r .cluster.status)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ "$cluster_status" != "Running" ]; do
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: CDW cluster status: $cluster_status                           "
        sleep 2
        cluster_status=$(cdp dw describe-cluster --cluster-id ${cluster_id} | jq -r .cluster.status)
    done
fi

# 2. Creating all vw

for item in $(echo ${dw_list} | jq -r '.[] | @base64'); do
    _jq() {
        echo ${item} | base64 --decode | jq -r ${1}
    }
    #echo ${item} | base64 --decode
    vw_name=$(_jq '.name')
    vw_type=$(_jq '.type')
    vw_id=$(cdp dw list-vws --cluster-id ${cluster_id} | jq -r '.vws[] | select(.name=="'${vw_name}'") | .id')
    if [ ${#vw_id} -gt 0 ]; then
        printf "\r${ALREADY_DONE}  $prefix: $vw_name already exists     "
        echo ""
    
    else
        dbc_id=$(cdp dw list-dbcs --cluster-id ${cluster_id} | jq -r .dbcs[0].id)
        result=$(cdp dw create-vw --cluster-id ${cluster_id} --dbc-id ${dbc_id} --vw-type ${vw_type} --name ${vw_name} 2>&1 >/dev/null)
        handle_exception $? $prefix "CDW VW creation" "$result"
        
        vw_id=$(cdp dw list-vws --cluster-id ${cluster_id} | jq -r '.vws[] | select(.name=="'${vw_name}'") | .id')
        vw_status=$(cdp dw describe-vw --cluster-id ${cluster_id} --vw-id ${vw_id} | jq -r .vw.status)

        spin='🌑🌒🌓🌔🌕🌖🌗🌘'
        while [ "$vw_status" != "Running" ]; do
            i=$(((i + 1) % 8))
            printf "\r${spin:$i:1}  $prefix: $vw_name vw status: $vw_status                           "
            sleep 2
            vw_status=$(cdp dw describe-vw --cluster-id ${cluster_id} --vw-id ${vw_id} | jq -r .vw.status)
        done

        printf "\r${CHECK_MARK}  $prefix: $vw_name vw status: $vw_status                                 "
        echo ""

    fi

done

echo ""