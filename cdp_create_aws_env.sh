#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <credential> <region> <key> <sg_cidr> [<subnet1>] [<subnet2>] [<subnet3>] [<vpc_id>] [<knox_sg_id>] [<default_sg_id>]

Description:
    Launches a CDP environment

Arguments:
    prefix:         prefix for your assets
    credentials:    CDP credential name
    region:         region for your env
    key:            name of the AWS key to re-use
    sg_cidr:        CIDR to open in your security group
    subnet1:        (optional) subnetId to be used for your environment (must be in different AZ than other subnets)
    subnet2:        (optional) subnetId to be used for your environment (must be in different AZ than other subnets)
    subnet3:        (optional) subnetId to be used for your environment (must be in different AZ than other subnets)
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

if [  $# -gt 11 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 

if [[ $# -gt 5 && $# -ne 11 ]] 
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
    subnet1=$6
    subnet2=$7
    subnet3=$8
    vpc=$9
    knox_sg_id=${10}
    default_sg_id=${11}

    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential} \
        --region ${region} \
        --security-access securityGroupIdForKnox="${knox_sg_id}",defaultSecurityGroupId="${default_sg_id}"  \
        --authentication publicKeyId="${key}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --subnet-ids "${subnet1}" "${subnet2}" "${subnet3}" \
        --vpc-id "${vpc}" \
        --s3-guard-table-name ${prefix}-cdp-table \
        --tags key="enddate",value="${END_DATE}" key="project",value="${PROJECT}" key="deploytool",value="one-click" 


else 
    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential}  \
        --region ${region} \
        --security-access cidr="${sg_cidr}"  \
        --authentication publicKeyId="${key}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --network-cidr "10.0.0.0/16" \
        --s3-guard-table-name ${prefix}-cdp-table \
        --tags key="enddate",value="${END_DATE}" key="project",value="${PROJECT}" key="deploytool",value="one-click" 
fi