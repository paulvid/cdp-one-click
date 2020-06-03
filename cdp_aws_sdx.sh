#!/bin/bash
source $(
    cd $(dirname $0)
    pwd -L
)/common.sh

display_usage() {
    echo "
Usage:
    $(basename "$0") <parameter_file> [<network_file>] [--help or -h]

Description:
    Creates AWS pre-requisites, CDP environment, data lake and a data hub clusters + tags the instances to the proper Cloudera policies

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)
    network_file:   (optional) location of your auto-generated network json file (setup to \${base_dir}/aws-pre-req/\${prefix}_aws_network.json)"

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

if [ $# -gt 2 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

# Parsing arguments
parse_parameters ${1}

# Creating environment
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating AWS CDP environment for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

# 1. Environment
env_status=$($base_dir/cdp_describe_env.sh $prefix | jq -r .environment.status)
if [ ${#env_status} -eq 0 ]; then
    env_status="NOT_FOUND"
fi

if [[ ("$env_status" != "NOT_FOUND") && (\
    "$env_status" != "AVAILABLE") && (\
    "$env_status" != "ENV_STOPPED") ]]; then
    handle_exception 2 "create environment" "Unknown environment status: $env_status"
fi

if [[ "$env_status" == "NOT_FOUND" ]]; then
    if [[ "$create_network" == "yes" ]]; then
        if [[ "$use_ccm" == "no" ]]; then
            network_file=${2}
            igw_id=$(cat ${network_file} | jq -r .InternetGatewayId)
            vpc_id=$(cat ${network_file} | jq -r .VpcId)
            subnet_id1a=$(cat ${network_file} | jq -r .Subnets[0])
            subnet_id1b=$(cat ${network_file} | jq -r .Subnets[1])
            subnet_id1c=$(cat ${network_file} | jq -r .Subnets[2])
            route_id=$(cat ${network_file} | jq -r .RouteTableId)
            knox_sg_id=$(cat ${network_file} | jq -r .KnoxGroupId)
            default_sg_id=$(cat ${network_file} | jq -r .DefaultGroupId)

            result=$($base_dir/cdp_create_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" $subnet_id1a $subnet_id1b $subnet_id1c $vpc_id $knox_sg_id $default_sg_id 2>&1 >/dev/null)
            handle_exception $? $prefix "environment creation" "$result"
        fi
        if [[ "$use_ccm" == "yes" ]]; then
            network_file=${2}

            igw_id=$(cat ${network_file} | jq -r .InternetGatewayId)
            vpc_id=$(cat ${network_file} | jq -r .VpcId)
            pub_sub_1=$(cat ${network_file} | jq -r .PublicSubnets[0])
            pub_sub_2=$(cat ${network_file} | jq -r .PublicSubnets[1])
            pub_sub_3=$(cat ${network_file} | jq -r .PublicSubnets[2])
            pub_route=$(cat ${network_file} | jq -r .PublicRouteTableId)
            nat_1=$(cat ${network_file} | jq -r .PublicNatGatewayIds[0])
            nat_2=$(cat ${network_file} | jq -r .PublicNatGatewayIds[1])
            nat_3=$(cat ${network_file} | jq -r .PublicNatGatewayIds[2])
            priv_sub_1=$(cat ${network_file} | jq -r .PrivateSubnets[0])
            priv_sub_2=$(cat ${network_file} | jq -r .PrivateSubnets[1])
            priv_sub_3=$(cat ${network_file} | jq -r .PrivateSubnets[2])
            priv_route_1=$(cat ${network_file} | jq -r .PrivateRouteTableIds[0])
            priv_route_2=$(cat ${network_file} | jq -r .PrivateRouteTableIds[1])
            priv_route_3=$(cat ${network_file} | jq -r .PrivateRouteTableIds[2])
            s3_endpoint=$(cat ${network_file} | jq -r .VPCEndpoints[0])
            dyanmo_endpoint=$(cat ${network_file} | jq -r .VPCEndpoints[1])
            knox_sg_id=$(cat ${network_file} | jq -r .KnoxGroupId)
            default_sg_id=$(cat ${network_file} | jq -r .DefaultGroupId)

            result=$($base_dir/cdp_create_private_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" $pub_sub_1 $pub_sub_2 $pub_sub_3 $priv_sub_1 $priv_sub_2 $priv_sub_3 $vpc_id $knox_sg_id $default_sg_id 2>&1 >/dev/null)
            handle_exception $? $prefix "environment creation" "$result"

        fi

    else
        if [[ "$use_ccm" == "no" ]]; then
            result=$($base_dir/cdp_create_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" 2>&1 >/dev/null)
            handle_exception $? $prefix "environment creation" "$result"
        fi
        if [[ "$use_ccm" == "yes" ]]; then
            result=$($base_dir/cdp_create_private_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" 2>&1 >/dev/null)
            handle_exception $? $prefix "environment creation" "$result"
        fi
    fi

    # Adding test for when env is not available yet

    env_describe_err=$($base_dir/cdp_describe_env.sh $prefix 2>&1 | grep NOT_FOUND)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [[ ${#env_describe_err} > 1 ]]; do
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: environment status: WAITING_FOR_API                             "
        sleep 2
        env_describe_err=$($base_dir/cdp_describe_env.sh $prefix 2>&1 | grep NOT_FOUND)
    done

    env_status=$($base_dir/cdp_describe_env.sh $prefix | jq -r .environment.status)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ "$env_status" != "AVAILABLE" ]; do
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: environment status: $env_status                             "
        sleep 2
        env_status=$($base_dir/cdp_describe_env.sh $prefix | jq -r .environment.status)

        if [[ "$env_status" == "CREATE_FAILED" ]]; then handle_exception 2 $prefix "environment creation" "Environment creation failed; Check UI for details"; fi
    done

    printf "\r${CHECK_MARK}  $prefix: environment status: $env_status                             "
    echo ""

    # 2. IDBroker mappings
    result=$($base_dir/cdp_aws_create_group_iam.sh $base_dir $prefix 2>&1 >/dev/null)
    handle_exception $? $prefix "idbroker mappings creation" "$result"

    echo "${CHECK_MARK}  $prefix: idbroker mappings set"
    echo ""
    echo ""
    echo "CDP environment for $prefix created!"
fi

if [[ "$env_status" == "AVAILABLE" ]]; then
    printf "\r${ALREADY_DONE}  $prefix: $prefix-cdp-env already available                             "
    echo ""
fi

if [[ "$env_status" == "ENV_STOPPED" ]]; then
    result=$(cdp environments start-environment --environment-name $prefix-cdp-env 2>&1 >/dev/null)
    handle_exception $? $prefix "environment start" "$result"
    env_status=$($base_dir/cdp_describe_env.sh $prefix | jq -r .environment.status)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ "$env_status" != "AVAILABLE" ]; do
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: environment status: $env_status                              "
        sleep 2
        env_status=$($base_dir/cdp_describe_env.sh $prefix | jq -r .environment.status)
    done

    printf "\r${CHECK_MARK}  $prefix: environment status: $env_status                                   "
fi

# Creating datalake
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating CDP datalake for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

# 3. Datalake
dl_status=$($base_dir/cdp_describe_dl.sh $prefix | jq -r .datalake.status)
if [ ${#dl_status} -eq 0 ]; then
    dl_status="NOT_FOUND"
fi
if [[ ("$dl_status" != "NOT_FOUND") && (\
    "$dl_status" != "RUNNING") && (\
    "$dl_status" != "STOPPED") ]]; then
    handle_exception 2 "create datalake" "Unknown datalake status: $dl_status"
fi

if [[ "$dl_status" == "NOT_FOUND" ]]; then
    result=$($base_dir/cdp_create_aws_datalake.sh $base_dir $prefix $RDS_HA 2>&1 >/dev/null)
    handle_exception $? $prefix "datalake creation" "$result"

    dl_status=$($base_dir/cdp_describe_dl.sh $prefix | jq -r .datalake.status)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ "$dl_status" != "RUNNING" ]; do
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: datalake status: $dl_status                              "
        sleep 2
        dl_status=$($base_dir/cdp_describe_dl.sh $prefix | jq -r .datalake.status)
        if [[ "$dl_status" == "CREATE_FAILED" ]]; then handle_exception 2 $prefix "Datalake creation" "Datalake creation failed; Check UI for details"; fi
    done

    printf "\r${CHECK_MARK}  $prefix: datalake status: $dl_status                             "
fi

if [[ "$dl_status" == "RUNNING" ]]; then
    printf "\r${ALREADY_DONE}  $prefix: $prefix-cdp-dl already running                             "
fi

if [[ "$dl_status" == "STOPPED" ]]; then
    dl_status=$($base_dir/cdp_describe_dl.sh $prefix | jq -r .datalake.status)
    if [ "$dl_status" != "RUNNING" ]; then
        result=$(cdp datalake start-datalake --datalake-name $prefix-cdp-dl 2>&1 >/dev/null)
        handle_exception $? $prefix "datalake start" "$result"
    fi
    dl_status=$($base_dir/cdp_describe_dl.sh $prefix | jq -r .datalake.status)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ "$dl_status" != "RUNNING" ]; do
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: datalake status: $dl_status                              "
        sleep 2
        dl_status=$($base_dir/cdp_describe_dl.sh $prefix | jq -r .datalake.status)
    done

    printf "\r${CHECK_MARK}  $prefix: datalake status: $dl_status                                 "
fi

# 4. Creating user workload password
result=$($base_dir/cdp_set_workload_pwd.sh ${workload_pwd} 2>&1 >/dev/null)
handle_exception $? $prefix "workload password setup" "$result"

echo ""
echo "${CHECK_MARK}  $prefix: workload password setup "

# 5. Syncing users
result=$($base_dir/cdp_sync_users.sh $prefix 2>&1 >/dev/null)
if [ $? -ne 255 ]; then
    handle_exception $? $prefix "syncing users" "$result"
    echo "${CHECK_MARK}  $prefix: user sync launched "
else
    echo "${ALREADY_DONE}  $prefix: user sync was already in progress "
fi

echo ""
echo ""
echo "CDP datalake for $prefix created!"
echo ""
