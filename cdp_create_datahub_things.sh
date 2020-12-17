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
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating CDP datahub clusters for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

# 1.1. Creating all clusters
for item in $(echo ${datahub_list} | jq -r '.[] | @base64'); do
    _jq() {
        echo ${item} | base64 --decode | jq -r ${1}
    }
    # echo ${item} | base64 --decode
    definition=$(_jq '.definition')
    custom_script=$(_jq '.custom_script')

    cluster_type=$(echo $base_dir/cdp-cluster-definitions/${cloud_provider}/$definition | awk -F "/" '{print $NF}' | awk -F "." '{print $1}')
    cluster_name=${prefix}-${cluster_type}

    dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name 2>/dev/null | jq -r .cluster.status)
    if [ ${#dh_status} -eq 0 ]; then
        dh_status="NOT_FOUND"
    fi

    if [[ "$dh_status" == "AVAILABLE" ]]; then
        printf "\r${ALREADY_DONE}  $prefix: $cluster_name already available                             "
        echo ""
    else

        if [[ "$dh_status" == "STOPPED" ]]; then
            if [ "$dh_status" != "AVAILABLE" ]; then
                result=$(cdp datahub start-cluster --cluster-name $cluster_name 2>&1 >/dev/null)
                handle_exception $? $prefix "datahub start" "$result"
            fi

            dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)

            spin='🌑🌒🌓🌔🌕🌖🌗🌘'
            while [ "$dh_status" != "AVAILABLE" ]; do
                i=$(((i + 1) % 8))
                printf "\r${spin:$i:1}  $prefix: $cluster_name datahub cluster status: $dh_status                           "
                sleep 2
                dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)
            done

            printf "\r${CHECK_MARK}  $prefix: $cluster_name datahub cluster status: $dh_status                            "
            echo ""
        else
            if [[ "$dh_status" == "NOT_FOUND" ]]; then
                if [[ ${cloud_provider} == "aws" ]]; then
                    result=$($base_dir/cdp_create_aws_dh_cluster.sh $prefix $base_dir/cdp-cluster-definitions/${cloud_provider}/$definition 2>&1 >/dev/null)
                    handle_exception $? $prefix "datahub creation" "$result"
                fi

                if [[ ${cloud_provider} == "az" ]]; then
                    result=$($base_dir/cdp_create_az_dh_cluster.sh $prefix $base_dir/cdp-cluster-definitions/${cloud_provider}/$definition 2>&1 >/dev/null)
                    handle_exception $? $prefix "datahub creation" "$result"
                fi

                if [[ ${cloud_provider} == "gcp" ]]; then

                    echo ''$base_dir'/cdp_create_gcp_dh_cluster.sh '$prefix' '$base_dir'/cdp-cluster-definitions/'${cloud_provider}'/'$definition''
                    exit 1

                    result=$($base_dir/cdp_create_gcp_dh_cluster.sh $prefix $base_dir/cdp-cluster-definitions/${cloud_provider}/$definition 2>&1 >/dev/null)
                    handle_exception $? $prefix "datahub creation" "$result"
                fi
            fi
            # fix to get around 500 random error
            cluster_type=$(echo $base_dir/cdp-cluster-definitions/${cloud_provider}/$definition | awk -F "/" '{print $NF}' | awk -F "." '{print $1}')
            cluster_name=${prefix}-${cluster_type}

            dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)

            spin='🌑🌒🌓🌔🌕🌖🌗🌘'
            while [ "$dh_status" != "AVAILABLE" ]; do
                i=$(((i + 1) % 8))
                printf "\r${spin:$i:1}  $prefix: $cluster_name datahub cluster status: $dh_status                           "
                sleep 2
                dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)
                if [[ "$dh_status" == "CREATE_FAILED" ]]; then handle_exception 2 $prefix "Datahub creation" "Datahub creation failed; Check UI for details"; fi
            done

            printf "\r${CHECK_MARK}  $prefix: $cluster_name datahub cluster status: $dh_status                            "
            echo ""

            if [ ${#custom_script} -gt 0 ]; then
                result=$(${base_dir}/cdp-dh-custom-scripts/${custom_script} ${param_file} 2>&1 >/dev/null)
                handle_exception $? $prefix "custom script application" "$result"

                echo "${CHECK_MARK}  $prefix: ${custom_script} applied for for $cluster_name"
            else
                echo "${CHECK_MARK}  $prefix: No custom scripts to apply for $cluster_name"
            fi

        fi
    fi
done

# # 1.2. Syncing users
# if [[ "$SYNC_USERS" == 1 ]]; then
#     $base_dir/cdp_sync_users.sh $prefix
# fi

echo ""
echo ""
echo "CDP datahub clusters for $prefix created!"
echo ""
