#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi
source $(
    cd $(dirname $0)
    pwd -L
)/common.sh

display_usage() {
    echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Creates AWS pre-requisites, CDP environment, data lake and a data hub clusters + tags the instances to the proper Cloudera policies

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)"

}
##########################################
# Arguments:                             #
#   $1 -> wait status (e.g. NOT_FOUND)   #
##########################################
get_env_status() {
        wait_status=$1
        ### COMMENTED UNTIL WE CAN REMOVE ERROR MESSAGES
        # result=$(
        #         { stdout=$($base_dir/cdp_describe_env.sh $prefix) ; } 2>&1
        #         printf "this is the separator"
        #         printf "%s\n" "$stdout"
        #     )
        # var_out=${result#*this is the separator}
        # var_err=${result%this is the separator*}
        # if [[ ${#var_out} -eq 0 ]]
        # then
        #     env_describe_err=$(echo $var_err | grep $wait_status)
        #     if [[ ${#env_describe_err} > 1 ]]
        #     then 
        #         env_status="WAITING_FOR_API"
        #     else
        #         handle_exception 2 $prefix "environment creation" $var_err
        #     fi
        # else
        #     env_status=$(echo ${var_out} | jq -r .environment.status)
        # fi
        status=$($base_dir/cdp_describe_env.sh $prefix | jq -r .environment.status)
        if [ ${#status} -lt 4 ]
        then
            env_status="WAITING_FOR_API"
        else
            env_status=$status
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
        printf "\r${CHECK_MARK}  $prefix: environment status: $env_status                           "
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
        printf "\r${CHECK_MARK}  $prefix: datalake status: $dl_status                                  "
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

if [ $# -gt 1 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

# Parsing arguments

# Parsing arguments
parse_parameters ${1}

# Creating environment
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating GCP CDP environment for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}

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
        if [[ "$env_status" == "NOT_FOUND" ]]; then
            if [[ "$use_priv_ips" == "no" ]]; then
                result=$($base_dir/cdp_create_gcp_env.sh $prefix $credential "$region" "$key" "$sg_cidr" "$workload_analytics" $create_network 2>&1 >/dev/null)
                handle_exception $? $prefix "environment creation" "$result"
                sleep 5
            else
                echo "Not yet supported!" >&2
                exit 1
            fi
        fi
       wait_for_deployment ENV AVAILABLE NOT_FOUND

        # 2. IDBroker mappings
        result=$($base_dir/cdp_gcp_create_group_iam.sh $base_dir $prefix 2>&1 >/dev/null)

        handle_exception $? $prefix "idbroker mappings creation" "$result"

        echo "${CHECK_MARK}  $prefix: idbroker mappings set"
        echo ""
        echo ""
        echo "CDP environment for $prefix created!"
        echo ""

    fi
fi
# Creating datalake
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
        if [[ "$dl_status" == "NOT_FOUND" ]]; then
            result=$($base_dir/cdp_create_gcp_datalake.sh $prefix $datalake_scale $RDS_HA 2>&1 >/dev/null)
            handle_exception $? $prefix "datalake creation" "$result"
        fi
        wait_for_deployment DL RUNNING UNKNOWN
    fi

fi

# 4. Creating user workload password
result=$($base_dir/cdp_set_workload_pwd.sh ${workload_pwd} 2>&1 >/dev/null)
handle_exception $? $prefix "workload password setup" "$result"

echo "${CHECK_MARK}  $prefix: workload password setup "
sleep $sleep_duration

# 5. Syncing users
if [[ "$SYNC_USERS" == 1 ]]; then
    $base_dir/cdp_sync_users.sh $prefix
fi

# 6. Create Bastion
if [[ "$create_bastion" == "yes" ]]; then
        echo "⛔  $prefix: one click does not support bastion hosts for GCP yet!" >&2
        exit 1
fi

echo ""
