#!/bin/bash 
set -o nounset
BASE_DIR=$(cd $(dirname $0); pwd -L)

display_usage() { 
    echo "
Usage:
    $(basename "$0") prefix base_dir [--help or -h] <prefix> 

Description:
    Deletes all 

Arguments:
    prefix:   prefix for your policies
    base_dir: base_dir of your one-click git
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
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

prefix=$1
base_dir=$2
env=${prefix}-cdp-env

# Getting the aws info
env_details=$(cdp environments describe-environment --environment-name $1-cdp-env)

# security groups
knox_sg_id=$(echo ${env_details} | jq -r .environment.securityAccess.securityGroupIdForKnox)
default_sg_id=$(echo ${env_details} | jq -r .environment.securityAccess.defaultSecurityGroupId)

# subnets
subnet_id1a=$(echo ${env_details} | jq -r .environment.network.subnetIds[0])
subnet_id1b=$(echo ${env_details} | jq -r .environment.network.subnetIds[1])
subnet_id1c=$(echo ${env_details} | jq -r .environment.network.subnetIds[2])

# vpc
vpc_id=$(echo ${env_details} | jq -r .environment.network.aws.vpcId)

# route 
route_info=$(aws ec2 describe-route-tables --filters Name="vpc-id",Values="$vpc_id")
route_id=$(echo ${route_info} | jq -r .RouteTables[0].RouteTableId)
igw_id=$(echo ${route_info} | jq -r .RouteTables[0].Routes[].GatewayId | grep igw)
echo "
    aws ec2 delete-security-group  --group-id $knox_sg_id
    aws ec2 delete-security-group  --group-id $default_sg_id
    aws ec2 delete-subnet  --subnet-id $subnet_id1a
    aws ec2 delete-subnet  --subnet-id $subnet_id1b
    aws ec2 delete-subnet  --subnet-id $subnet_id1c
    aws ec2 detach-internet-gateway  --internet-gateway-id $igw_id --vpc-id $vpc_id
    aws ec2 delete-route-table  --route-table-id $route_id
    aws ec2 delete-vpc  --vpc-id $vpc_id
    aws ec2 delete-internet-gateway  --internet-gateway-id $igw_id

    " > $base_dir/aws-pre-req/tmp_network/${prefix}_aws_delete_network.sh
    chmod a+x $base_dir/aws-pre-req/tmp_network/${prefix}_aws_delete_network.sh


