#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Creates AWS pre-requisites

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)"

}




# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 1 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 1 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

# Parsing arguments
parse_parameters ${1}


# AWS pre-requisites (per env)
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating AWS pre-requisites for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i=1;i<=$prefix_length;i++))
do
    underline=${underline}"▔"
done
echo ${underline}
echo ""


# 1. Bucket
if [[ "$($base_dir/aws-pre-req/aws_check_if_resource_exists.sh $prefix bucket)" == "no" ]]
then
    result=$($base_dir/aws-pre-req/aws_create_bucket.sh  $prefix $region 2>&1 > /dev/null)
    handle_exception $? $prefix "bucket creation" "$result"

    bucket=${prefix}-cdp-bucket
    echo "${CHECK_MARK}  $prefix: bucket $bucket created"
else
    bucket=${prefix}-cdp-bucket
    echo "${ALREADY_DONE}  $prefix: bucket $bucket already created"
fi


# 3. Creating Roles & Policies
if [[ "$($base_dir/aws-pre-req/aws_check_if_resource_exists.sh $prefix iam)" == "no" ]]
then
    result=$($base_dir/aws-pre-req/aws_create_policies.sh $prefix 2>&1 > /dev/null)
    handle_exception $? $prefix "policy creation" "$result"
    echo "${CHECK_MARK}  $prefix: new policies created"

    result=$($base_dir/aws-pre-req/aws_create_roles.sh  $prefix 2>&1 > /dev/null)
    handle_exception $? $prefix "role creation" "$result"
    echo "${CHECK_MARK}  $prefix: new roles created"
else
    echo "${ALREADY_DONE}  $prefix: iam already created"
fi






# 5. Creating Network
if [[ "$create_network" == "yes" ]]
then
    if [[ "$($base_dir/aws-pre-req/aws_check_if_resource_exists.sh $prefix network)" == "no" ]]
    then
        if [[ "$use_ccm" == "no" ]]
        then
            result=$(
                { stdout=$($base_dir/aws-pre-req/aws_create_network.sh $prefix $region $sg_cidr) ; } 2>&1
                printf "this is the separator"
                printf "%s\n" "$stdout"
            )
            var_out=${result#*this is the separator}
            var_err=${result%this is the separator*}

            if [ "$var_err" ]
            then
                handle_exception 1 $prefix "network creation" "$var_err"
            fi

            created_network=$var_out
            mkdir $base_dir/aws-pre-req/tmp_network > /dev/null 2>&1
            echo $var_out > $base_dir/aws-pre-req/tmp_network/${prefix}_aws_network.json 

            igw_id=$(echo $created_network | jq -r .InternetGatewayId)
            vpc_id=$(echo $created_network | jq -r .VpcId)
            subnet_id1a=$(echo $created_network | jq -r .PublicSubnets[0])
            subnet_id1b=$(echo $created_network | jq -r .PublicSubnets[1])
            subnet_id1c=$(echo $created_network | jq -r .PublicSubnets[2])
            route_id=$(echo $created_network | jq -r .RouteTableId)
            knox_sg_id=$(echo $created_network | jq -r .KnoxGroupId)
            default_sg_id=$(echo $created_network | jq -r .DefaultGroupId)


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


            echo "${CHECK_MARK}  $prefix: new network created"
        fi

        if [[ "$use_ccm" == "yes" ]]
        then
            result=$(
                { stdout=$($base_dir/aws-pre-req/aws_create_private_network.sh $prefix $region $sg_cidr) ; } 2>&1
                printf "this is the separator"
                printf "%s\n" "$stdout"
            )
            var_out=${result#*this is the separator}
            var_err=${result%this is the separator*}

            if [ "$var_err" ]
            then
                handle_exception 1 $prefix "network creation" "$var_err"
            fi

            created_network=$var_out
            mkdir $base_dir/aws-pre-req/tmp_network > /dev/null 2>&1
            echo $var_out > $base_dir/aws-pre-req/tmp_network/${prefix}_aws_network.json 

            igw_id=$(echo $created_network | jq -r .InternetGatewayId)
            vpc_id=$(echo $created_network | jq -r .VpcId)
            pub_sub_1=$(echo $created_network | jq -r .PublicSubnets[0])
            pub_sub_2=$(echo $created_network | jq -r .PublicSubnets[1])
            pub_sub_3=$(echo $created_network | jq -r .PublicSubnets[2])
            pub_route=$(echo $created_network | jq -r .PublicRouteTableId)
            nat_1=$(echo $created_network | jq -r .PublicNatGatewayIds[0])
            nat_2=$(echo $created_network | jq -r .PublicNatGatewayIds[1])
            nat_3=$(echo $created_network | jq -r .PublicNatGatewayIds[2])
            priv_sub_1=$(echo $created_network | jq -r .PrivateSubnets[0])
            priv_sub_2=$(echo $created_network | jq -r .PrivateSubnets[1])
            priv_sub_3=$(echo $created_network | jq -r .PrivateSubnets[2])
            priv_route_1=$(echo $created_network | jq -r .PrivateRouteTableIds[0])
            priv_route_2=$(echo $created_network | jq -r .PrivateRouteTableIds[1])
            priv_route_3=$(echo $created_network | jq -r .PrivateRouteTableIds[2])
            s3_endpoint=$(echo $created_network | jq -r .VPCEndpoints[0])
            dyanmo_endpoint=$(echo $created_network | jq -r .VPCEndpoints[1])
            knox_sg_id=$(echo $created_network | jq -r .KnoxGroupId)
            default_sg_id=$(echo $created_network | jq -r .DefaultGroupId)


            echo "    
            aws ec2 delete-nat-gateway --nat-gateway-id $nat_1
            aws ec2 delete-nat-gateway --nat-gateway-id $nat_2
            aws ec2 delete-nat-gateway --nat-gateway-id $nat_3
            sleep 60
            aws ec2 delete-security-group  --group-id $knox_sg_id
            aws ec2 delete-security-group  --group-id $default_sg_id

            aws ec2 delete-subnet  --subnet-id $pub_sub_1
            aws ec2 delete-subnet  --subnet-id $pub_sub_2
            aws ec2 delete-subnet  --subnet-id $pub_sub_3
            aws ec2 delete-subnet  --subnet-id $priv_sub_1
            aws ec2 delete-subnet  --subnet-id $priv_sub_2
            aws ec2 delete-subnet  --subnet-id $priv_sub_3

            aws ec2 detach-internet-gateway  --internet-gateway-id $igw_id --vpc-id $vpc_id
            
            aws ec2 delete-route-table  --route-table-id $pub_route
            aws ec2 delete-route-table  --route-table-id $priv_route_1
            aws ec2 delete-route-table  --route-table-id $priv_route_2
            aws ec2 delete-route-table  --route-table-id $priv_route_3

            aws ec2 delete-vpc-endpoint --vpc-endpoint-ids $s3_endpoint $dyanmo_endpoint

            aws ec2 delete-vpc  --vpc-id $vpc_id
            aws ec2 delete-internet-gateway  --internet-gateway-id $igw_id
        " > $base_dir/aws-pre-req/tmp_network/${prefix}_aws_delete_network.sh
            chmod a+x $base_dir/aws-pre-req/tmp_network/${prefix}_aws_delete_network.sh


            echo "${CHECK_MARK}  $prefix: new network created"
        fi  
    else
        echo "${ALREADY_DONE}  $prefix: vpc $prefix-cdp-vpc already created"
    fi
fi

# 6. Creating cross-account role / credentials if needed

# response=$(cdp environments list-credentials --credential-name ${credential} 2> /dev/null | jq -r .credentials[0].credentialName | wc -l)

if [[ "$generate_credential" == "yes" ]]
then

    # Purging old accounts
    if [[ "$($base_dir/aws-pre-req/aws_check_if_resource_exists.sh $prefix ca)" == "no" ]]
    then
        result=$($base_dir/aws-pre-req/aws_purge_ca_roles_policies.sh $prefix $generate_minimal_cross_account 2>&1 > /dev/null)
        handle_exception $? $prefix "cross account purge" "$result"
        echo "${CHECK_MARK}  $prefix: cross account purged"
    fi

    cred=$(cdp environments list-credentials | jq -r .credentials[].credentialName | grep ${credential})
    if [[ ${credential} == $cred ]]
    then
        result=$(cdp environments delete-credential --credential-name ${credential} 2>&1 > /dev/null)
        handle_exception $? $prefix "credential purge" "$result"
        echo "${CHECK_MARK}  $prefix: credential purged"
    fi

    # Creating account
    result=$($base_dir/aws-pre-req/aws_create_cross_account.sh $prefix "$external_id" "$ext_acct_id" $generate_minimal_cross_account 2>&1 > /dev/null)
    handle_exception $? $prefix "cross account creation" "$result"
    echo "${CHECK_MARK}  $prefix: cross account created"

    ca_role_arn=$(aws iam get-role  --role-name ${prefix}-cross-account-role | jq -r .Role.Arn)


    result=$($base_dir/cdp_create_aws_credential.sh ${credential} ${ca_role_arn}  2>&1 > /dev/null)
    handle_exception $? $prefix "credential creation" "$result"
    echo "${CHECK_MARK}  $prefix: new credential created"
fi


echo ""
echo "AWS pre-requisites created for $prefix!"
echo ""