#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <credential> <region> <key> [<subnet1>] [<subnet2>] [<subnet3>] [<vpc_id>] [<knox_sg_id>] [<default_sg_id>]

Description:
    Launches a CDP environment

Arguments:
    prefix:         prefix for your assets
    credentials:    CDP credential name
    region:         region for your env
    key:            name of the AWS key to re-use
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

if [  $# -gt 10 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 

if [[ $# -gt 4 && $# -ne 10 ]] 
then 
    echo "Wrong number of arguments!" >&2
    display_usage
    exit 1
fi 


prefix=$1
credential=$2
region=$3
key=$4
if [  $# -gt 4 ]
then
    subnet1=$5
    subnet2=$6
    subnet3=$7
    vpc=$8
    knox_sg_id=$9
    default_sg_id=${10}

    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential} \
        --region ${region} \
        --security-access securityGroupIdForKnox="${knox_sg_id}",defaultSecurityGroupId="${default_sg_id}"  \
        --authentication publicKeyId="${key}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --subnet-ids "${subnet1}" "${subnet2}" "${subnet3}" \
        --vpc-id "${vpc}" \
        --s3-guard-table-name ${prefix}-cdp-table


else 
    cdp environments create-aws-environment --environment-name ${prefix}-cdp-env \
        --credential-name ${credential}  \
        --region ${region} \
        --security-access cidr="0.0.0.0/0"  \
        --authentication publicKeyId="${key}" \
        --log-storage storageLocationBase="${prefix}-cdp-bucket",instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/${prefix}-log-role" \
        --network-cidr "10.0.0.0/16" \
        --s3-guard-table-name ${prefix}-cdp-table
fi