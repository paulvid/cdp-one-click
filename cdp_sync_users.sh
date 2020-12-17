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
    $(basename "$0")  <prefix> [--help or -h]

Description:
    Syncs user to environment

Arguments:
    prefix:         prefix for your assets
    --help or -h:   displays this help"

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

prefix=$1
CHECK_MARK="✅"
# Create groups
env_crn=$(cdp environments describe-environment --environment-name $prefix-cdp-env | jq -r .environment.crn)

spin='🌑🌒🌓🌔🌕🌖🌗🌘'
result=$(
    { stdout=$(cdp environments sync-all-users --environment-name $env_crn); } 2>&1
    printf "this is the separator"
    printf "%s\n" "$stdout"
)
var_out=${result#*this is the separator}
var_err=${result%this is the separator*}

if [ "$var_err" ]; then
    error_code=$(echo $var_err | awk -F "(" '{print $2}' | awk '{print $6}')
    if [[ "$error_code" == "CONFLICT;" ]]; then

        previous_op_id=$(echo $var_err | awk -F "[" '{print $2}' | awk -F " " '{print $2}')

        sync_status=$(cdp environments sync-status --operation-id $previous_op_id | jq -r .status)
        while [[ $sync_status != "COMPLETED" ]]; do
            i=$(((i + 1) % 8))
            printf "\r${spin:$i:1}  $prefix: sync status: WAITING_FOR_PREVIOUS ($sync_status)     "
            sleep 2
            sync_status=$(cdp environments sync-status --operation-id $previous_op_id | jq -r .status)
        done

        result=$(cdp environments sync-all-users --environment-name $env_crn)
        handle_exception $? $prefix "syncing users" "$result"

        operation_id=$(echo $result | jq -r .operationId)
        sync_status=$(cdp environments sync-status --operation-id $operation_id | jq -r .status)
        while [[ $sync_status != "COMPLETED" ]]; do
            i=$(((i + 1) % 8))
            printf "\r${spin:$i:1}  $prefix: sync status: $sync_status                                                     "
            sleep 2
            sync_status=$(cdp environments sync-status --operation-id $operation_id | jq -r .status)
        done
        printf "\r${CHECK_MARK}  $prefix: sync status: $sync_status                                       "

    else
        handle_exception 1 $prefix "syncing users" "$result"
    fi
else
    operation_id=$(echo $var_out | jq -r .operationId)
    sync_status=$(cdp environments sync-status --operation-id $operation_id | jq -r .status)
    while [[ $sync_status != "COMPLETED" ]]; do
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: sync status: $sync_status                              "
        sleep 2
        sync_status=$(cdp environments sync-status --operation-id $operation_id | jq -r .status)
    done
    printf "\r${CHECK_MARK}  $prefix: sync status: $sync_status                              "
fi
