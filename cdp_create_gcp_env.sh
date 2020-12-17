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
    $(basename "$0") [--help or -h] <prefix> <credential> <region> <key> <sg_cidr> (<network_created>)

Description:
    Launches a CDP Azure environment

Arguments:
    prefix:             prefix for your assets
    credentials:        CDP credential name
    region:             region for your env
    key:                name of the Azure key to re-use
    sg_cidr:            CIDR to open in your security group
    workload_analytics: enable workload analytics
    network_created:    (optional) flag to see if network was created (possible values: yes or no)
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 6 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 7 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 
flatten_tags() {
    tags=$1
    flattened_tags=""
    for item in $(echo ${tags} | jq -r '.[] | @base64'); do
        _jq() {
            echo ${item} | base64 --decode | jq -r ${1}
        }
        #echo ${item} | base64 --decode
        key=$(_jq '.key')
        value=$(_jq '.value')
        flattened_tags=$flattened_tags" key=\"$key\",value=\"$value\""
    done
    echo $flattened_tags
}

prefix=$1
credential=$2
region=$3
key=$4
sg_cidr=$5
workload_analytics=$6
network_created=$7
owner=$(cdp iam get-user | jq -r .user.email)
if [  $# -gt 6 ] 
then 
    network_created=$7
    network_name="$prefix-cdp-network"
    subnet_name="${network_name}-subnet-1"
fi
project=$(gcloud config get-value project)

if [[ "$network_created" == "no" ]]
then
        echo "⛔  $prefix: CDP does not support creation of networks for GCP yet! Use the flag create_network in your paramters file" >&2
        exit 1
else
        cdp environments create-gcp-environment  --environment-name ${prefix}-cdp-env \
        --credential-name ${credential} \
        --region "${region}" \
        --public-key "${key}" \
        --log-storage storageLocationBase="gs://${prefix}-cdp-logs/",serviceAccountEmail="${prefix}-log-sa@${project}.iam.gserviceaccount.com" \
        --existing-network-params networkName="${network_name}",subnetNames=["${subnet_name}"],sharedProjectName="${project}"  \
        --enable-tunnel \
        $workload_analytics \
        --use-public-ip 


        # --tags $(flatten_tags "$TAGS") \ commenting out for now
fi


