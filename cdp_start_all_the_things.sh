#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Starts every datahub clusters, datalake and environment based on prefix in parameters file

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


echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃ Starting to start all the things ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
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

# 1. Starting datahub clusters
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Starting CDP datahub clusters for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i=1;i<=$prefix_length;i++))
do
    underline=${underline}"▔"
done
echo ${underline}


all_clusters=$(cdp datahub list-clusters --environment-name $prefix-cdp-env 2> /dev/null)

for row in $(echo ${all_clusters} | jq -r '.clusters[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    cluster_name=$(_jq '.clusterName')


    cdp datahub  start-cluster --cluster-name $cluster_name > /dev/null 2>&1


    dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ "$dh_status" != "AVAILABLE" ]
    do 
        i=$(( (i+1) %8 ))
        printf "\r${spin:$i:1}  $prefix: $cluster_name datahub cluster status: $dh_status                           "
        sleep 2
        dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name | jq -r .cluster.status)
    done

        printf "\r${CHECK_MARK}  $prefix: $cluster_name datahub cluster status: $dh_status                            "
        echo ""
done

echo ""
# 2. Stopping SDX
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Starting SDX (environment & datalake) for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i=1;i<=$prefix_length;i++))
do
    underline=${underline}"▔"
done
echo ${underline}
echo "🚫  $prefix: SDX start is not yet supported by CLI"
echo ""
echo ""

echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃ Finished to start all the things ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"