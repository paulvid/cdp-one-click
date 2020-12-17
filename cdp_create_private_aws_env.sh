#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 
source $(cd $(dirname $0); pwd -L)/common.sh
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <credential> <region> <key> <sg_cidr> [<pub_sub_1>] [<pub_sub_2>] [<pub_sub_3>] [<priv_sub_1>] [<priv_sub_2>] [<priv_sub_3>] [<vpc_id>] [<knox_sg_id>] [<default_sg_id>]

Description:
    Launches a CDP environment

Arguments:
    prefix:         prefix for your assets
    credentials:    CDP credential name
    region:         region for your env
    key:            name of the AWS key to re-use
    sg_cidr:        CIDR to open in your security group
    workload_analytics  enable workload analytics
    pub_sub_1:      (optional) public subnetId 1 to be used for your env
    pub_sub_2:      (optional) public subnetId 2 to be used for your env
    pub_sub_3:      (optional) public subnetId 3 to be used for your env
    priv_sub_1:     (optional) public subnetId 1 to be used for your env
    priv_sub_2:     (optional) public subnetId 2 to be used for your env
    priv_sub_3:     (optional) public subnetId 3 to be used for your env
    vpc:            (optional) vpcId associated with subnets
    knox_sg_id:     (optional) knox security GroupId
    default_sg_id:  (optional) default security GroupId
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
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

if [  $# -gt 15 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 

if [[ $# -gt 6 && $# -ne 15 ]] 
then 
    echo "Wrong number of arguments!" >&2
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
owner=$(cdp iam get-user | jq -r .user.email)

if [  $# -gt 6 ]
then
    pub_sub_1=$7
    pub_sub_2=$8
    pub_sub_3=$9
    priv_sub_1=${10}
    priv_sub_2=${11}
    priv_sub_3=${12}
    vpc=${13}
    knox_sg_id=${14}
    default_sg_id=${15}

    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential} \
        --region ${region} \
        --security-access securityGroupIdForKnox="${knox_sg_id}",defaultSecurityGroupId="${default_sg_id}"  \
        --authentication publicKeyId="${key}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --subnet-ids "${pub_sub_1}" "${pub_sub_2}" "${pub_sub_3}" "${priv_sub_1}" "${priv_sub_2}" "${priv_sub_3}" \
        --vpc-id "${vpc}" \
        --s3-guard-table-name ${prefix}-cdp-table \
        --enable-tunnel \
        $workload_analytics \
        --tags $(flatten_tags "$TAGS") 


else 
    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential}  \
        --region ${region} \
        --security-access cidr="${sg_cidr}"  \
        --authentication publicKeyId="${key}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --network-cidr "10.0.0.0/16" \
        --s3-guard-table-name ${prefix}-cdp-table \
        --enable-tunnel \
        $workload_analytics \
        --tags $(flatten_tags "$TAGS")  \
        --create-private-subnets
fi