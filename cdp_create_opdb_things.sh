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
    Creates all ml workspaces listed in your paramater json file (run this script after creating your env + datalake)

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)
   "
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
parse_parameters ${1}

# 1. Creating datahub cluster
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating CDP op databases for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

# 1.1. Creating all clusters
for item in $(echo ${op_db_list} | jq -r '.[] | @base64'); do
    _jq() {
        echo ${item} | base64 --decode | jq -r ${1}
    }
    #echo ${item} | base64 --decode
    database_name=$(_jq '.database_name')
    env_name=${prefix}-cdp-env
    db_status=$(cdp opdb describe-database --environment-name $env_name --database-name $database_name 2>/dev/null | jq -r .databaseDetails.status)
    if [ ${#db_status} -eq 0 ]; then
        db_status="NOT_FOUND"
    fi

    if [[ ("$db_status" == "AVAILABLE") ]]; then
        printf "\r${ALREADY_DONE}  $prefix: $database_name already available     "
        echo ""
    else
        if [[ ("$db_status" == "NOT_FOUND") ]]; then
             result=$(cdp opdb create-database --environment-name $env_name --database-name $database_name 2>&1 >/dev/null)
            handle_exception $? $prefix "op db creation" "$result"
        fi
        db_status=$(cdp opdb describe-database --environment-name $env_name --database-name $database_name 2>/dev/null | jq -r .databaseDetails.status)

        spin='🌑🌒🌓🌔🌕🌖🌗🌘'
        while [ "$db_status" != "AVAILABLE" ]; do
            i=$(((i + 1) % 8))
            printf "\r${spin:$i:1}  $prefix: $database_name database status: $db_status                           "
            sleep 2
            db_status=$(cdp opdb describe-database --environment-name $env_name --database-name $database_name 2>/dev/null | jq -r .databaseDetails.status)
        done

        printf "\r${CHECK_MARK}  $prefix: $database_name database status: $db_status                                 "
        echo ""

    fi

done

echo ""