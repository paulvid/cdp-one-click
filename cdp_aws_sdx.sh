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

##########################################
# Arguments:                             #
#   $1 -> wait status (e.g. NOT_FOUND)   #
##########################################
get_env_status() {
        wait_status=$1
        result=$(
                { stdout=$($base_dir/cdp_describe_env.sh $prefix) ; } 2>&1
                printf "this is the separator"
                printf "%s\n" "$stdout"
            )
        var_out=${result#*this is the separator}
        var_err=${result%this is the separator*}
        if [[ ${#var_out} -eq 0 ]]
        then
            env_describe_err=$(echo $var_err | grep $wait_status)
            if [[ ${#env_describe_err} > 1 ]]
            then 
                env_status="WAITING_FOR_API"
            else
                handle_exception 2 $prefix "environment creation" $var_err
            fi
        else
            env_status=$(echo ${var_out} | jq -r .environment.status)
        fi

        echo $env_status
}


########################################
# Arguments:                           #
#   $1 -> wait status (e.g. UNKNOWN)   #
########################################
get_dl_status() {
        wait_status=$1
        result=$(
                { stdout=$($base_dir/cdp_describe_dl.sh $prefix) ; } 2>&1
                printf "this is the separator"
                printf "%s\n" "$stdout"
            )
        var_out=${result#*this is the separator}
        var_err=${result%this is the separator*}
        if [[ ${#var_out} -eq 0 ]]
        then
            dl_describe_err=$(echo $var_err | grep $wait_status)
            if [[ ${#dl_describe_err} > 1 ]]
            then 
                dl_status="WAITING_FOR_API"
            else
                handle_exception 2 $prefix "datalake creation" $var_err
            fi
        else
            dl_status=$(echo ${var_out} | jq -r .datalake.status)
        fi

        echo $dl_status
}


##########################################
# Arguments:                             #
#   $1 -> type (ENV/DL)                  #
#   $2 -> complete status (e.g. RUNNING) #
#   $3 -> wait status (e.g. NOT_FOUND)   #
##########################################
wait_for_deployment() {

    type=$1
    complete_status=$2
    wait_status=$3
    spin='🌑🌒🌓🌔🌕🌖🌗🌘'

    if [[ "$type" == "ENV" ]]
    then

        env_status=$(get_env_status $wait_status)
        while [ "$env_status" != "$complete_status" ]; do
            if [[ "$env_status" == "CREATE_FAILED" ]]; then handle_exception 2 $prefix "environment creation" "Environment creation failed; Check UI for details"; exit 2; fi
            i=$(((i + 1) % 8))
            printf "\r${spin:$i:1}  $prefix: environment status: $env_status                              "
            sleep 2
            env_status=$(get_env_status $wait_status)
        done
        printf "\r${CHECK_MARK}  $prefix: environment status: $env_status                                     "
        echo ""
    fi


    if [[ "$type" == "DL" ]]
    then
        dl_status=$(get_dl_status $wait_status)
        
        while [ "$dl_status" != "$complete_status" ]; do
            if [[ "$dl_status" == "CREATE_FAILED" ]]; then handle_exception 2 $prefix "datalake creation" "Datalake creation failed; Check UI for details"; exit 2; fi
            i=$(((i + 1) % 8))
            printf "\r${spin:$i:1}  $prefix: datalake status: $dl_status                              "
            sleep 2
            dl_status=$(get_dl_status $wait_status)
        done
        printf "\r${CHECK_MARK}  $prefix: datalake status: $dl_status                                    "
        echo ""
    fi



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
env_status=$($base_dir/cdp_describe_env.sh $prefix 2>/dev/null | jq -r .environment.status)
if [ ${#env_status} -eq 0 ]; then
    env_status="NOT_FOUND"
fi

if [[ "$env_status" == "AVAILABLE" ]]; then
    printf "\r${ALREADY_DONE}  $prefix: $prefix-cdp-env already available                             "
    echo ""
    echo ""
else

    if [[ "$env_status" == "ENV_STOPPED" ]]; then
        result=$(cdp environments start-environment --environment-name $prefix-cdp-env 2>&1 >/dev/null)
        handle_exception $? $prefix "environment start" "$result"
        wait_for_deployment ENV AVAILABLE NOT_FOUND

    else
        if [ "$env_status" == "NOT_FOUND" ]; then
            if [[ "$create_network" == "yes" ]]; then
                if [[ "$use_ccm" == "no" ]]; then
                    network_file=${2}
                    igw_id=$(cat ${network_file} | jq -r .InternetGatewayId)
                    vpc_id=$(cat ${network_file} | jq -r .VpcId)
                    subnet_id1a=$(cat ${network_file} | jq -r .PublicSubnets[0])
                    subnet_id1b=$(cat ${network_file} | jq -r .PublicSubnets[1])
                    subnet_id1c=$(cat ${network_file} | jq -r .PublicSubnets[2])
                    route_id=$(cat ${network_file} | jq -r .RouteTableId)
                    knox_sg_id=$(cat ${network_file} | jq -r .KnoxGroupId)
                    default_sg_id=$(cat ${network_file} | jq -r .DefaultGroupId)

                    result=$($base_dir/cdp_create_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" "$workload_analytics" $subnet_id1a $subnet_id1b $subnet_id1c $vpc_id $knox_sg_id $default_sg_id 2>&1 >/dev/null)
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

                    result=$($base_dir/cdp_create_private_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" "$workload_analytics" $pub_sub_1 $pub_sub_2 $pub_sub_3 $priv_sub_1 $priv_sub_2 $priv_sub_3 $vpc_id $knox_sg_id $default_sg_id 2>&1 >/dev/null)
                    handle_exception $? $prefix "environment creation" "$result"

                fi

            else
                if [[ $USE_EXISTING_NETWORK == "yes" ]]; then
                    if [[ "$use_ccm" == "no" ]]; then
                        network_file=$EXISTING_NETWORK_FILE
                        igw_id=$(cat ${network_file} | jq -r .InternetGatewayId)
                        vpc_id=$(cat ${network_file} | jq -r .VpcId)
                        subnet_id1a=$(cat ${network_file} | jq -r .PublicSubnets[0])
                        subnet_id1b=$(cat ${network_file} | jq -r .PublicSubnets[1])
                        subnet_id1c=$(cat ${network_file} | jq -r .PublicSubnets[2])
                        route_id=$(cat ${network_file} | jq -r .RouteTableId)
                        knox_sg_id=$(cat ${network_file} | jq -r .KnoxGroupId)
                        default_sg_id=$(cat ${network_file} | jq -r .DefaultGroupId)

                        result=$($base_dir/cdp_create_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" "$workload_analytics" $subnet_id1a $subnet_id1b $subnet_id1c $vpc_id $knox_sg_id $default_sg_id 2>&1 >/dev/null)
                        handle_exception $? $prefix "environment creation" "$result"
                    fi
                    if [[ "$use_ccm" == "yes" ]]; then
                        network_file=$EXISTING_NETWORK_FILE

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

                        result=$($base_dir/cdp_create_private_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" "$workload_analytics" $pub_sub_1 $pub_sub_2 $pub_sub_3 $priv_sub_1 $priv_sub_2 $priv_sub_3 $vpc_id $knox_sg_id $default_sg_id 2>&1 >/dev/null)
                        handle_exception $? $prefix "environment creation" "$result"

                    fi
                else  
                    if [[ "$use_ccm" == "no" ]]; then
                        result=$($base_dir/cdp_create_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" "$workload_analytics" 2>&1 >/dev/null)
                        handle_exception $? $prefix "environment creation" "$result"
                    fi
                    if [[ "$use_ccm" == "yes" ]]; then
                        result=$($base_dir/cdp_create_private_aws_env.sh $prefix $credential $region "$key" "$sg_cidr" "$workload_analytics" 2>&1 >/dev/null)
                        handle_exception $? $prefix "environment creation" "$result"
                    fi
                fi
            fi
        fi
        # Adding test for when env is not available yet

        wait_for_deployment ENV AVAILABLE NOT_FOUND
       
        # 2. IDBroker mappings
        result=$($base_dir/cdp_aws_create_group_iam.sh $base_dir $prefix 2>&1 >/dev/null)
        handle_exception $? $prefix "idbroker mappings creation" "$result"

        echo "${CHECK_MARK}  $prefix: idbroker mappings set"
        echo ""
        echo ""
        echo "CDP environment for $prefix created!"
    fi
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
dl_status=$($base_dir/cdp_describe_dl.sh $prefix 2>/dev/null | jq -r .datalake.status)
if [ ${#dl_status} -eq 0 ]; then
    dl_status="NOT_FOUND"
fi
if [[ "$dl_status" == "RUNNING" ]]; then
    printf "\r${ALREADY_DONE}  $prefix: $prefix-cdp-dl already running                             "
    echo ""
else

    if [[ "$dl_status" == "STOPPED" ]]; then
        dl_status=$($base_dir/cdp_describe_dl.sh $prefix | jq -r .datalake.status)
        if [ "$dl_status" != "RUNNING" ]; then
            result=$(cdp datalake start-datalake --datalake-name $prefix-cdp-dl 2>&1 >/dev/null)
            handle_exception $? $prefix "datalake start" "$result"
        fi

        wait_for_deployment DL RUNNING UNKNOWN
        

    else
        if [ "$dl_status" == "NOT_FOUND" ]; then
            result=$($base_dir/cdp_create_aws_datalake.sh $base_dir $prefix $datalake_scale $RDS_HA 2>&1 >/dev/null)
            handle_exception $? $prefix "datalake creation" "$result"
        fi
        wait_for_deployment DL RUNNING UNKNOWN
    fi
fi
# 4. Creating user workload password
result=$($base_dir/cdp_set_workload_pwd.sh ${workload_pwd} 2>&1 >/dev/null)
handle_exception $? $prefix "workload password setup" "$result"

echo "${CHECK_MARK}  $prefix: workload password setup "

# 5. Syncing users
if [[ "$SYNC_USERS" == 1 ]]; then
    $base_dir/cdp_sync_users.sh $prefix
fi

echo ""
