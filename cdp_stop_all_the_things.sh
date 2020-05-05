#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Stops every datahub clusters, datalake and environment based on prefix in parameters file

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


echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃ Starting to stop all the things ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Parsing parameters and running pre-checks:"
echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"

# Parsing arguments
parse_parameters ${1}
echo "${CHECK_MARK}  parameters parsed from ${1}"

# Running pre-req checks
run_pre_checks
echo "${CHECK_MARK}  pre-checks done"
echo ""

# 1. Stopping datahub clusters
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Stopping CDP datahub clusters for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i=1;i<=$prefix_length;i++))
do
    underline=${underline}"▔"
done
echo ${underline}

wait_for_dh_stop=false
all_clusters=$(cdp datahub list-clusters --environment-name $prefix-cdp-env 2> /dev/null)

for row in $(echo ${all_clusters} | jq -r '.clusters[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    cluster_name=$(_jq '.clusterName')

    dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)
    if [ "$dh_status" != "STOPPED" ]
    then
        result=$(cdp datahub stop-cluster --cluster-name $cluster_name 2>&1 > /dev/null)
        handle_exception $? $prefix "datahub stop" "$result"
    fi

    dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ "$dh_status" != "STOPPED" ]
    do 
        i=$(( (i+1) %8 ))
        printf "\r${spin:$i:1}  $prefix: $cluster_name datahub cluster status: $dh_status                           "
        sleep 2
        dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)
        wait_for_dh_stop=true
    done

    printf "\r${CHECK_MARK}  $prefix: $cluster_name datahub cluster status: $dh_status                            "

done

# Stopping DataHub cluster's take longer than when the CDP CLI actually says they are STOPPED.  Wait 2 minutes for any stopping cluster's to complete. Don't wait if we never needed to stop one.
if [ "$wait_for_dh_stop" = true ]
then
    sleep 120
fi

# 2. Stopping SDX
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Stopping SDX (environment & datalake) for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i=1;i<=$prefix_length;i++))
do
    underline=${underline}"▔"
done
echo ${underline}

# 2.1 Datalake

dl_status=$($base_dir/cdp_describe_dl.sh  $prefix | jq -r .datalake.status)
if [ "$dl_status" != "STOPPED" ]
then
    result=$(cdp datalake stop-datalake --datalake-name $prefix-cdp-dl 2>&1 > /dev/null)
    handle_exception $? $prefix "datalake stop" "$result"
fi
dl_status=$($base_dir/cdp_describe_dl.sh  $prefix | jq -r .datalake.status)

spin='🌑🌒🌓🌔🌕🌖🌗🌘'
while [ "$dl_status" != "STOPPED" ]
do 
    i=$(( (i+1) %8 ))
    printf "\r${spin:$i:1}  $prefix: datalake status: $dl_status                              "
    sleep 2
    dl_status=$($base_dir/cdp_describe_dl.sh  $prefix | jq -r .datalake.status)
done

printf "\r${CHECK_MARK}  $prefix: datalake status: $dl_status                                 "

# 2.2 Environment

env_status=$($base_dir/cdp_describe_env.sh  $prefix | jq -r .environment.status)
if [ "$env_status" != "ENV_STOPPED" ]
then
    result=$(cdp environments stop-environment --environment-name $prefix-cdp-env 2>&1 > /dev/null)
    handle_exception $? $prefix "environment stop" "$result"
fi
env_status=$($base_dir/cdp_describe_env.sh  $prefix | jq -r .environment.status)

spin='🌑🌒🌓🌔🌕🌖🌗🌘'
while [ "$env_status" != "ENV_STOPPED" ]
do 
    i=$(( (i+1) %8 ))
    printf "\r${spin:$i:1}  $prefix: environment status: $env_status                              "
    sleep 2
    env_status=$($base_dir/cdp_describe_env.sh  $prefix | jq -r .environment.status)
done

printf "\r${CHECK_MARK}  $prefix: environment status: $env_status                                   "

echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃ Finished to stop all the things ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
