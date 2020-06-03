#!/bin/bash
source $(
    cd $(dirname $0)
    pwd -L
)/common.sh

display_usage() {
    echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Creates all datahub clusters listed in your paramater json file (run this script after creating your env + datalake)

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
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating CDP ml workspaces for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

# 1.1. Creating all clusters
for item in $(echo ${ml_workspace_list} | jq -r '.[] | @base64'); do
    _jq() {
        echo ${item} | base64 --decode | jq -r ${1}
    }
    #echo ${item} | base64 --decode
    definition=$(_jq '.definition')
    enable_workspace=$(_jq '.enable_workspace')
    workspace_name=${prefix}-$(echo $definition | awk -F "." '{print $1}' | sed s/\_/\-/g)
    env_name=${prefix}-cdp-env
    workspace_status=$($base_dir/cdp_describe_ml_workspace.sh $env_name $workspace_name 2>/dev/null | jq -r .workspace.instanceStatus)
    if [ ${#workspace_status} -eq 0 ]; then
        workspace_status="NOT_FOUND"
    fi

    if [[ ("$workspace_status" != "NOT_FOUND") && (\
        "$workspace_status" != "installation:finished") ]]; then
        handle_exception 2 "create ml workspace" "Unknown ml workspace status: $workspace_status"
    fi

    if [[ ("$workspace_status" != "NOT_FOUND") ]]; then
        workspace_name=${prefix}-$(echo $definition | awk -F "." '{print $1}' | sed s/\_/\-/g)

        workspace_template=$(sed "s/<project>/${PROJECT}/g;s/<owner>/${owner}/g;s/<enddate>/${END_DATE}/g;s/<prefix>/${prefix}/g" $base_dir/cml-workspace-definitions/$definition)
        echo $workspace_template >$base_dir/cml-workspace-definitions/${prefix}_$definition
        result=$($base_dir/cdp_create_ml_workspace.sh $prefix $base_dir/cml-workspace-definitions/${prefix}_$definition ${workspace_name} ${cloud_provider} ${enable_workspace} 2>&1 >/dev/null)
        handle_exception $? $prefix "ml workspace creation" "$result"

        rm $base_dir/cml-workspace-definitions/${prefix}_$definition 2>&1 >/dev/null
        env_name=${prefix}-cdp-env

        workspace_status=$($base_dir/cdp_describe_ml_workspace.sh $env_name $workspace_name | jq -r .workspace.instanceStatus)

        spin='🌑🌒🌓🌔🌕🌖🌗🌘'
        while [ "$workspace_status" != "installation:finished" ]; do
            i=$(((i + 1) % 8))
            printf "\r${spin:$i:1}  $prefix: $workspace_name ml workspace instance status: $workspace_status                           "
            sleep 2
            workspace_status=$($base_dir/cdp_describe_ml_workspace.sh $env_name $workspace_name | jq -r .workspace.instanceStatus)
        done

        printf "\r${CHECK_MARK}  $prefix: $workspace_name ml workspace instance status: $workspace_status                           "
        echo ""

    fi

    if [[ ("$workspace_status" != "installation:finished") ]]; then
        printf "\r${ALREADY_DONE}  $prefix: $workspace_name already set     "
        echo ""
    fi
done
