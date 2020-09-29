#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Creates AWS pre-requisites, CDP environment, data lake, data hub clusters, ml workspaces, + tags the instances to the proper Cloudera policies

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)

Example:
    ./cdp_create_all_the_things.sh /Users/pvidal/Documents/sme-cloud/cdp-automation/AWS/aws-one-click-env/parameters.json"

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

if [  $# -gt 4 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

param_file=${1}
RDS_HA=1
COST_CHECK=1
SYNC_USERS=1
while (( "$#" )); do
  case "$1" in
    --no-db-ha)
      RDS_HA=0
      shift
      ;;
    --no-cost-check)
      COST_CHECK=0
      shift
      ;;
    --no-sync-users)
      SYNC_USERS=0
      shift
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

export RDS_HA=$RDS_HA
export SYNC_USERS=$SYNC_USERS

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃ Starting to create all the things ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Parsing parameters and running pre-checks:"
echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"

# Parsing arguments
parse_parameters ${param_file}
echo "${CHECK_MARK}  parameters parsed from ${param_file}"

# Running pre-req checks
run_pre_checks
echo "${CHECK_MARK}  pre-checks done"

# Evaluating costs
if [ $COST_CHECK -eq 1 ]
then
    ${base_dir}/cdp_review_costs.sh ${param_file}
    code=$?
    if [ $code -ne 0 ]
    then 
        exit 2 
    fi
    echo ""
    echo "${CHECK_MARK}  costs accepted"
 
fi
echo ""

if [[ ${cloud_provider} == "aws" ]]
then
    # 1. AWS pre-reqs
    ${base_dir}/cdp_aws_pre_reqs.sh ${param_file}
    handle_exception $? $prefix "creating AWS pre-requisites" "Error creating AWS pre-requisites"

    # 2. AWS SDX
     ${base_dir}/cdp_aws_sdx.sh ${param_file} ${base_dir}/aws-pre-req/tmp_network/${prefix}_aws_network.json
    handle_exception $? $prefix "creating AWS SDX" "Error creating AWS SDX"

fi

if [[ ${cloud_provider} == "az" ]]
then
    # 1. Azure pre-reqs
    ${base_dir}/cdp_az_pre_reqs.sh ${param_file}
    handle_exception $? $prefix "creating Azure pre-requisites" "Error creating Azure pre-requisites"

     # 2. Azure SDX
     ${base_dir}/cdp_az_sdx.sh ${param_file}
    handle_exception $? $prefix "creating Azure SDX" "Error creating Azure SDX"
   
fi

# 4. Creating datahub cluster if we have at least one definition
list_size=$(echo ${datahub_list} | jq -r .[] 2> /dev/null | wc -l)
definition_size=$(echo ${datahub_list} | jq -r .[0].definition 2> /dev/null |  awk '{print length}')

if ([ $list_size -gt 0 ] && [ $definition_size -gt 0 ])
then
    $base_dir/cdp_create_datahub_things.sh $param_file
    handle_exception $? $prefix "creating datahubs" "Error creating datahubs"
fi


# 5. Creating ml workspaces if we have at least definition
list_size=$(echo ${ml_workspace_list} | jq -r .[] 2> /dev/null | wc -l)
definition_size=$(echo ${ml_workspace_list} | jq -r .[0].definition 2> /dev/null |  awk '{print length}')

if ([ $list_size -gt 0 ] && [ $definition_size -gt 0 ])
then
    $base_dir/cdp_create_ml_things.sh $param_file
    handle_exception $? $prefix "creating ml workspaces" "Error ml workspaces"
fi

# 6. Creating op databases if we have at least definition
list_size=$(echo ${op_db_list} | jq -r .[] 2> /dev/null | wc -l)
database_name_size=$(echo ${op_db_list} | jq -r .[0].database_name 2> /dev/null |  awk '{print length}')

if ([ $list_size -gt 0 ] && [ $database_name_size -gt 0 ])
then
    $base_dir/cdp_create_opdb_things.sh $param_file
    handle_exception $? $prefix "creating op databases" "Error op databases"
fi

# 7. Creating CDW if we have at least definition
list_size=$(echo ${dw_list} | jq -r .[] 2> /dev/null | wc -l)
vw_name_size=$(echo ${dw_list} | jq -r .[0].name 2> /dev/null |  awk '{print length}')

if ([ $list_size -gt 0 ] && [ $vw_name_size -gt 0 ])
then
    $base_dir/cdp_create_dw_things.sh $param_file
    handle_exception $? $prefix "creating CDW" "Error in CDW creation"
fi
echo ""
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃ Finished to create all the things ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"