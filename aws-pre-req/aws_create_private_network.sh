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
        #K in key and V in value must be capped for AWS
        flattened_tags=$flattened_tags" Key=\"$key\",Value=\"$value\""
    done
    echo $flattened_tags
}

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


# 1. Creating VPC
vpc_id=$(aws ec2 create-vpc --cidr 10.10.0.0/16 | jq -r .Vpc.VpcId)
aws ec2 create-tags --resources $vpc_id --tags Key=Name,Value="$prefix-cdp-vpc" $(flatten_tags "$TAGS") > /dev/null 2>&1

# 2. Creating public subnets

# 2.1. Subnets
public_sub_1=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.10.0.0/24 --availability-zone "$region"a | jq -r .Subnet.SubnetId)
public_sub_2=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.10.1.0/24 --availability-zone "$region"b | jq -r .Subnet.SubnetId)
public_sub_3=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.10.2.0/24 --availability-zone "$region"c | jq -r .Subnet.SubnetId)
aws ec2 create-tags --resources $public_sub_1 --tags Key=Name,Value="$prefix-pub-subnet-1" $(flatten_tags "$TAGS") > /dev/null 2>&1
aws ec2 create-tags --resources $public_sub_2 --tags Key=Name,Value="$prefix-pub-subnet-2" $(flatten_tags "$TAGS") > /dev/null 2>&1
aws ec2 create-tags --resources $public_sub_3 --tags Key=Name,Value="$prefix-pub-subnet-3" $(flatten_tags "$TAGS") > /dev/null 2>&1


# 2.2. Internet gateway
igw_id=$(aws ec2 create-internet-gateway | jq -r .InternetGateway.InternetGatewayId)
aws ec2 create-tags --resources $igw_id --tags Key=Name,Value="$prefix-igw" $(flatten_tags "$TAGS") > /dev/null 2>&1

aws ec2 attach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id > /dev/null 2>&1
aws ec2 modify-vpc-attribute --enable-dns-support "{\"Value\":true}" --vpc-id $vpc_id > /dev/null 2>&1
aws ec2 modify-vpc-attribute --enable-dns-hostnames "{\"Value\":true}" --vpc-id $vpc_id > /dev/null 2>&1



# 2.3. Route
route_pub=$(aws ec2 create-route-table --vpc-id $vpc_id | jq -r .RouteTable.RouteTableId)
aws ec2 create-tags --resources $route_pub --tags Key=Name,Value="$prefix-pub-route" $(flatten_tags "$TAGS") > /dev/null 2>&1

aws ec2 create-route --route-table-id $route_pub --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id > /dev/null 2>&1 

aws ec2 associate-route-table  --subnet-id $public_sub_1 --route-table-id $route_pub > /dev/null 2>&1
aws ec2 associate-route-table  --subnet-id $public_sub_2 --route-table-id $route_pub > /dev/null 2>&1
aws ec2 associate-route-table  --subnet-id $public_sub_3 --route-table-id $route_pub > /dev/null 2>&1


# 3. Creating private subnets

# 3.1. Subnets
private_sub_1=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.10.160.0/19 --availability-zone "$region"a | jq -r .Subnet.SubnetId)
private_sub_2=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.10.192.0/19 --availability-zone "$region"b | jq -r .Subnet.SubnetId)
private_sub_3=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.10.224.0/19 --availability-zone "$region"c | jq -r .Subnet.SubnetId)
aws ec2 create-tags --resources $private_sub_1 --tags Key=Name,Value="$prefix-priv-subnet-1" $(flatten_tags "$TAGS") > /dev/null 2>&1
aws ec2 create-tags --resources $private_sub_2 --tags Key=Name,Value="$prefix-priv-subnet-2" $(flatten_tags "$TAGS") > /dev/null 2>&1
aws ec2 create-tags --resources $private_sub_3 --tags Key=Name,Value="$prefix-priv-subnet-3" $(flatten_tags "$TAGS") > /dev/null 2>&1

# 3.1. NAT gateways
alloc_id_1=$(aws ec2 allocate-address --domain vpc | jq -r .AllocationId)
alloc_id_2=$(aws ec2 allocate-address --domain vpc | jq -r .AllocationId)
alloc_id_3=$(aws ec2 allocate-address --domain vpc | jq -r .AllocationId)

nat_1=$(aws ec2 create-nat-gateway --subnet-id $public_sub_1 --allocation-id $alloc_id_1 | jq -r .NatGateway.NatGatewayId)
sleep 30
nat_2=$(aws ec2 create-nat-gateway --subnet-id $public_sub_2 --allocation-id $alloc_id_2 | jq -r .NatGateway.NatGatewayId)
sleep 30
nat_3=$(aws ec2 create-nat-gateway --subnet-id $public_sub_3 --allocation-id $alloc_id_3 | jq -r .NatGateway.NatGatewayId)
sleep 30
aws ec2 create-tags --resources $nat_1 --tags Key=Name,Value="$prefix-priv-subnet-1" $(flatten_tags "$TAGS") > /dev/null 2>&1
aws ec2 create-tags --resources $nat_2 --tags Key=Name,Value="$prefix-priv-subnet-1" $(flatten_tags "$TAGS") > /dev/null 2>&1
aws ec2 create-tags --resources $nat_3 --tags Key=Name,Value="$prefix-priv-subnet-1" $(flatten_tags "$TAGS") > /dev/null 2>&1

# 3.2. Routes
route_priv_1=$(aws ec2 create-route-table --vpc-id $vpc_id | jq -r .RouteTable.RouteTableId)
route_priv_2=$(aws ec2 create-route-table --vpc-id $vpc_id | jq -r .RouteTable.RouteTableId)
route_priv_3=$(aws ec2 create-route-table --vpc-id $vpc_id | jq -r .RouteTable.RouteTableId)
aws ec2 create-tags --resources $route_priv_1 --tags Key=Name,Value="$prefix-priv-route-1" $(flatten_tags "$TAGS") > /dev/null 2>&1
aws ec2 create-tags --resources $route_priv_2 --tags Key=Name,Value="$prefix-priv-route-2" $(flatten_tags "$TAGS") > /dev/null 2>&1
aws ec2 create-tags --resources $route_priv_3 --tags Key=Name,Value="$prefix-priv-route-3" $(flatten_tags "$TAGS") > /dev/null 2>&1

aws ec2 create-route --route-table-id $route_priv_1 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $nat_1 > /dev/null 2>&1
aws ec2 create-route --route-table-id $route_priv_2 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $nat_2 > /dev/null 2>&1
aws ec2 create-route --route-table-id $route_priv_3 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $nat_3 > /dev/null 2>&1


aws ec2 associate-route-table  --subnet-id $private_sub_1 --route-table-id $route_priv_1 > /dev/null 2>&1
aws ec2 associate-route-table  --subnet-id $private_sub_2 --route-table-id $route_priv_2 > /dev/null 2>&1
aws ec2 associate-route-table  --subnet-id $private_sub_3 --route-table-id $route_priv_3 > /dev/null 2>&1


# 4. VPC endpoints
s3_endpoint=$(aws ec2 create-vpc-endpoint --vpc-id $vpc_id --service-name com.amazonaws.${region}.s3 | jq -r .VpcEndpoint.VpcEndpointId)
dynamo_endpoint=$(aws ec2 create-vpc-endpoint --vpc-id $vpc_id --service-name com.amazonaws.${region}.dynamodb | jq -r .VpcEndpoint.VpcEndpointId)

aws ec2 modify-vpc-endpoint --vpc-endpoint-id $s3_endpoint --add-route-table-ids $route_pub $route_priv_1 $route_priv_2 $route_priv_3 > /dev/null 2>&1
aws ec2 modify-vpc-endpoint --vpc-endpoint-id $dynamo_endpoint --add-route-table-ids $route_pub $route_priv_1 $route_priv_2 $route_priv_3 > /dev/null 2>&1

# 5. Security groups


knox_sg_id=$(aws ec2 create-security-group --description "AWS CDP Knox security group" --group-name "$prefix-knox-sg" --vpc-id $vpc_id | jq -r .GroupId)
aws ec2 create-tags --resources $knox_sg_id --tags Key=Name,Value="$prefix-knox-sg" $(flatten_tags "$TAGS") > /dev/null 2>&1


aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 22 --cidr $sg_cidr
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 0-65535 --cidr 10.10.0.0/16  > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol udp --port 0-65535 --cidr 10.10.0.0/16 > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 0-65535 --cidr 10.10.224.0/19  > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol udp --port 0-65535 --cidr 10.10.224.0/19 > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol tcp --port 443 --cidr $sg_cidr > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol icmp --port -1 --cidr 10.10.0.0/16 > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $knox_sg_id --protocol icmp --port -1 --cidr 10.10.224.0/19 > /dev/null 2>&1


default_sg_id=$(aws ec2 create-security-group --description "AWS default security group" --group-name "$prefix-default-sg" --vpc-id $vpc_id | jq -r .GroupId)
aws ec2 create-tags --resources $default_sg_id --tags Key=Name,Value="$prefix-default-sg" $(flatten_tags "$TAGS") > /dev/null 2>&1

aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 0-65535 --cidr 10.10.0.0/16  > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol udp --port 0-65535 --cidr 10.10.0.0/16 > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 0-65535 --cidr 10.10.224.0/19  > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol udp --port 0-65535 --cidr 10.10.224.0/19 > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol icmp --port -1 --cidr 10.10.0.0/16 > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol icmp --port -1 --cidr 10.10.224.0/19 > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $default_sg_id --protocol tcp --port 22 --cidr $sg_cidr


echo "{\"VpcId\": \"$vpc_id\",   
       \"InternetGatewayId\": \"$igw_id\",
       \"PublicSubnets\": [\"$public_sub_1\", \"$public_sub_2\", \"$public_sub_3\"],
       \"PublicRouteTableId\": \"$route_pub\", 
       \"PublicNatGatewayIds\": [\"$nat_1\", \"$nat_2\", \"$nat_3\"], 
       \"PrivateSubnets\": [\"$private_sub_1\", \"$private_sub_2\", \"$private_sub_3\"],
       \"PrivateRouteTableIds\": [\"$route_priv_1\", \"$route_priv_2\", \"$route_priv_3\"],
       \"VPCEndpoints\": [\"$s3_endpoint\", \"$dynamo_endpoint\"],
       \"KnoxGroupId\": \"$knox_sg_id\" , 
       \"DefaultGroupId\": \"$default_sg_id\"}"
