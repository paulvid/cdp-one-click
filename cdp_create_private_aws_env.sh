#!/bin/bash 
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
if [  $# -lt 4 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 14 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 

if [[ $# -gt 5 && $# -ne 14 ]] 
then 
    echo "Wrong number of arguments!" >&2
    display_usage
    exit 1
fi 


prefix=$1
credential=$2
region=$3
key=$4
sg_cidr=$5
if [  $# -gt 5 ]
then
    pub_sub_1=$6
    pub_sub_2=$7
    pub_sub_3=$8
    priv_sub_1=${9}
    priv_sub_2=${10}
    priv_sub_3=${11}
    vpc=${12}
    knox_sg_id=${13}
    default_sg_id=${14}

    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential} \
        --region ${region} \
        --security-access securityGroupIdForKnox="${knox_sg_id}",defaultSecurityGroupId="${default_sg_id}"  \
        --authentication publicKeyId="${key}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --subnet-ids "${pub_sub_1}" "${pub_sub_2}" "${pub_sub_3}" "${priv_sub_1}" "${priv_sub_2}" "${priv_sub_3}" \
        --vpc-id "${vpc}" \
        --s3-guard-table-name ${prefix}-cdp-table \
        --enable-tunnel


else 
    echo "Operation not supported: you can't enable CCM without creating network (see https://jira.cloudera.com/browse/CB-7187)"  >&2
    exit 1
    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential}  \
        --region ${region} \
        --security-access cidr="${sg_cidr}"  \
        --authentication publicKeyId="${key}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --network-cidr "10.0.0.0/16" \
        --s3-guard-table-name ${prefix}-cdp-table \ 
        --enable-tunnel \
        #--create-private-network
fi