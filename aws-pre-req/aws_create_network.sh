#!/bin/bash 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <region> <sg_cidr>

Description:
    Creates network assets for CDP env demployment

Arguments:
    prefix:         prefix of your assets
    region:         AWS region
    sg_cidr:        CIDR to open in your security group
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 3 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 3 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

prefix=$1
region=$2
sg_cidr=$3

igw_id=$(aws ec2 create-internet-gateway | jq -r .InternetGateway.InternetGatewayId)

vpc_id=$(aws ec2 create-vpc --cidr 10.0.0.0/16 | jq -r .Vpc.VpcId)
aws ec2 create-tags --resources $vpc_id --tags Key=Name,Value="$prefix-cdp-vpc"


aws ec2 attach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id
aws ec2 modify-vpc-attribute --enable-dns-support "{\"Value\":true}" --vpc-id $vpc_id
aws ec2 modify-vpc-attribute --enable-dns-hostnames "{\"Value\":true}" --vpc-id $vpc_id

route_id=$(aws ec2 create-route-table --vpc-id $vpc_id | jq -r .RouteTable.RouteTableId)

aws ec2 create-route --route-table-id $route_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id > /dev/null 2>&1

subnet_id1a=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.0.0/19 --availability-zone "$region"a | jq -r .Subnet.SubnetId)
subnet_id1b=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.160.0/19 --availability-zone "$region"b | jq -r .Subnet.SubnetId)
subnet_id1c=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.64.0/19 --availability-zone "$region"c | jq -r .Subnet.SubnetId)


aws ec2 modify-subnet-attribute --subnet-id $subnet_id1a --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $subnet_id1b --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $subnet_id1c --map-public-ip-on-launch

aws ec2 associate-route-table  --subnet-id $subnet_id1a --route-table-id $route_id > /dev/null 2>&1
aws ec2 associate-route-table  --subnet-id $subnet_id1b --route-table-id $route_id > /dev/null 2>&1
aws ec2 associate-route-table  --subnet-id $subnet_id1c --route-table-id $route_id > /dev/null 2>&1

knox_sg_id=$(aws ec2 create-security-group --description "AWS CDP Knox security group" --group-name "$prefix-knox-sg" --vpc-id $vpc_id | jq -r .GroupId)

aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 22 --cidr $sg_cidr  >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 443 --cidr $sg_cidr >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 443 --cidr 52.36.110.208/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 443 --cidr 52.40.165.49/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 443 --cidr 35.166.86.177/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 9443 --cidr $sg_cidr >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 9443 --cidr 52.36.110.208/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 9443 --cidr 52.40.165.49/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 9443 --cidr 35.166.86.177/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 0-65535 --cidr 10.0.0.0/16 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol udp --port 0-65535 --cidr 10.0.0.0/16 >> /dev/null 2>&1


default_sg_id=$(aws ec2 create-security-group --description "AWS default security group" --group-name "$prefix-default-sg" --vpc-id $vpc_id | jq -r .GroupId)

aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 22 --cidr $sg_cidr>> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 443 --cidr $sg_cidr >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 443 --cidr 52.36.110.208/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 443 --cidr 52.40.165.49/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 443 --cidr 35.166.86.177/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 9443 --cidr $sg_cidr >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 9443 --cidr 52.36.110.208/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 9443 --cidr 52.40.165.49/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 9443 --cidr 35.166.86.177/32 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 5432 --cidr 10.0.0.0/16 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 0-65535 --cidr 10.0.0.0/16 >> /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol udp --port 0-65535 --cidr 10.0.0.0/16 >> /dev/null 2>&1


echo "{\"InternetGatewayId\": \"$igw_id\", \"VpcId\": \"$vpc_id\", \"Subnets\": [\"$subnet_id1a\", \"$subnet_id1b\", \"$subnet_id1c\"], \"RouteTableId\": \"$route_id\", \"KnoxGroupId\": \"$knox_sg_id\" , \"DefaultGroupId\": \"$default_sg_id\"}"
