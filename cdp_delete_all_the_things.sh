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
    Deletes AWS pre-requisites, CDP environment, data lake, data hub clusters, and ML workspaces

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)
    --help or -h:   displays this help

Example:
    ./cdp_delete_all_the_things.sh /Users/pvidal/Documents/sme-cloud/cdp-automation/AWS/aws-one-click-env/parameters.json"

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

echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃ Starting to delete all the things ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
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

# 1. Deleting op databases
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Deleting CDP op databases for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

env_name=${prefix}-cdp-env
env_crn=$(cdp environments describe-environment --environment-name ${prefix}-cdp-env  2>/dev/null | jq -r .environment.crn)
all_dbs=$(cdp opdb list-databases | jq -r '.databases[] | select(.environmentCrn=="'${env_crn}'") | .databaseName' 2>/dev/null)

for db in $(echo ${all_dbs}); do

    cdp opdb drop-database --environment-name $env_name --database-name $db >/dev/null 2>&1

    wc=$(cdp opdb describe-database --environment-name $env_name --database-name $db 2>/dev/null | jq -r .databaseDetails.status | wc -l)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ $wc -ne 0 ]; do
        db_status=$(cdp opdb describe-database --environment-name $env_name --database-name $db 2>/dev/null | jq -r .databaseDetails.status)
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: $db database status: $db_status                           "
        sleep 2
        wc=$(cdp opdb describe-database --environment-name $env_name --database-name $db 2>/dev/null | jq -r .databaseDetails.status | wc -l)
    done

    printf "\r${CHECK_MARK}  $prefix: $db database status: NOT_FOUND                                 "
    echo ""
done

echo "${CHECK_MARK}  $prefix: no op database remaining"

echo ""
echo "CDP op databases for $prefix deleted!"
echo ""


# 2. Deleting ml workspace
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Deleting CDP ml workspaces for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

all_workspaces=$(cdp ml list-workspaces | jq -r '.workspaces[] | select(.environmentName=="'${prefix}'-cdp-env") | .instanceName' 2>/dev/null)

for workspace in $(echo ${all_workspaces}); do

    $base_dir/cdp_delete_ml_workspace.sh ${prefix}-cdp-env ${workspace} >/dev/null 2>&1

    wc=$($base_dir/cdp_describe_ml_workspace.sh ${prefix}-cdp-env $workspace 2>/dev/null | jq -r .workspace.instanceStatus | wc -l)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ $wc -ne 0 ]; do
        workspace_status=$($base_dir/cdp_describe_ml_workspace.sh ${prefix}-cdp-env $workspace 2>/dev/null | jq -r .workspace.instanceStatus)
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: $workspace_name ml workspace instance status: $workspace_status                    "
        sleep 2
        wc=$($base_dir/cdp_describe_ml_workspace.sh ${prefix}-cdp-env $workspace 2>/dev/null | jq -r .workspace.instanceStatus | wc -l)
    done

    printf "\r${CHECK_MARK}  $prefix: $workspace_name ml workspace instance status: NOT_FOUND                    "
    echo ""
done

echo "${CHECK_MARK}  $prefix: no ML workspace remaining"

echo ""
echo "CDP ml workspaces for $prefix deleted!"
echo ""

# 3. Deleting datahub clusters
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Deleting CDP datahub clusters for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

all_clusters=$(cdp datahub list-clusters --environment-name $prefix-cdp-env 2>/dev/null)

for row in $(echo ${all_clusters} | jq -r '.clusters[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }
    cluster_name=$(_jq '.clusterName')

    cdp datahub delete-cluster --cluster-name $cluster_name >/dev/null 2>&1

    wc=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name 2>/dev/null | jq -r .cluster.status | wc -l)

    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ $wc -ne 0 ]; do
        dh_status=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name 2>/dev/null | jq -r .cluster.status)
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: $cluster_name datahub cluster status: $dh_status                     "
        sleep 2
        wc=$($base_dir/cdp_describe_dh_cluster.sh $cluster_name 2>/dev/null | jq -r .cluster.status | wc -l)
    done

    printf "\r${CHECK_MARK}  $prefix: $cluster_name datahub cluster status: NOT_FOUND                    "
    echo ""
done

echo "${CHECK_MARK}  $prefix: no datahub cluster remaining"
echo ""
echo "CDP datahub clusters for $prefix deleted!"
echo ""

# Generating network deletion
$base_dir/aws-pre-req/aws_generate_delete_network.sh $prefix $base_dir >/dev/null 2>&1

# 4. Deleting datalake
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Deleting CDP datalake for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

cdp datalake delete-datalake --datalake-name $prefix-cdp-dl >/dev/null 2>&1

wc=$($base_dir/cdp_describe_dl.sh $prefix 2>/dev/null | jq -r .datalake.status | wc -l)

spin='🌑🌒🌓🌔🌕🌖🌗🌘'
while [ $wc -ne 0 ]; do
    dl_status=$($base_dir/cdp_describe_dl.sh $prefix 2>/dev/null | jq -r .datalake.status)
    i=$(((i + 1) % 8))
    printf "\r${spin:$i:1}  $prefix: datalake status: $dl_status                      "
    sleep 2
    wc=$($base_dir/cdp_describe_dl.sh $prefix 2>/dev/null | jq -r .datalake.status | wc -l)
done
printf "\r${CHECK_MARK}  $prefix: datalake status: NOT_FOUND                                             "

echo ""
echo ""
echo "CDP datalake for $prefix deleted!"
echo ""

# 5. Deleting environment
echo ""
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Deleting CDP environment for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}

wc=$($base_dir/cdp_describe_env.sh $prefix 2>/dev/null | jq -r .environment.status | wc -l)
if [ $wc -ne 0 ]; then
    if [[ ${cloud_provider} == "az" ]]; then
        env_rg_name=$(cdp environments describe-environment --environment-name $prefix-cdp-env | jq -r .environment.network.azure.resourceGroupName)
    fi

    if [[ ${cloud_provider} == "aws" ]]; then
        env_vpc_id=$(cdp environments describe-environment --environment-name $prefix-cdp-env | jq -r .environment.network.aws.vpcId)
    fi

    cdp environments delete-environment --environment-name $prefix-cdp-env >/dev/null 2>&1


    spin='🌑🌒🌓🌔🌕🌖🌗🌘'
    while [ $wc -ne 0 ]; do
        env_status=$($base_dir/cdp_describe_env.sh $prefix 2>/dev/null | jq -r .environment.status)
        i=$(((i + 1) % 8))
        printf "\r${spin:$i:1}  $prefix: environment status: $env_status                       "
        sleep 2
        wc=$($base_dir/cdp_describe_env.sh $prefix 2>/dev/null | jq -r .environment.status | wc -l)
    done

    if [[ "$create_network" == "no" ]]; then
        if [[ ${cloud_provider} == "az" ]]; then
            wc=$(az group show --name $env_rg_name 2>/dev/null | jq -r .properties.provisioningState | wc -l)
            while [ $wc -ne 0 ]; do
                rg_status=$(az group show --name $env_rg_name 2>/dev/null | jq -r .properties.provisioningState)
                i=$(((i + 1) % 8))
                printf "\r${spin:$i:1}  $prefix: environment status: NO_CDP_API_RESPONSE ($env_rg_name rg status: $rg_status)       "
                sleep 2                    
                wc=$(az group show --name $env_rg_name 2>/dev/null | jq -r .properties.provisioningState | wc -l)
            done
        fi


        if [[ ${cloud_provider} == "aws" ]]; then
            wc=$(aws ec2 describe-vpcs | jq -r .Vpcs[].VpcId | grep $env_vpc_id | wc -l)
            while [ $wc -ne 0 ]; do
                i=$(((i + 1) % 8))
                printf "\r${spin:$i:1}  $prefix: environment status: NO_CDP_API_RESPONSE (waiting for $env_vpc_id to be deleted)       "
                sleep 2                    
                wc=$(aws ec2 describe-vpcs | jq -r .Vpcs[].VpcId | grep $env_vpc_id | wc -l)
            done

        fi
    fi
fi


printf "\r${CHECK_MARK}  $prefix: environment status: NOT_FOUND                                                                             "

echo ""
echo ""
echo "CDP environment for $prefix deleted!"
echo ""

# 6. Deleting cloud assets
if [[ ${cloud_provider} == "aws" ]]; then
    echo "⏱  $(date +%H%Mhrs)"
    echo ""
    echo "Deleting AWS assets for $prefix:"
    underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
    for ((i = 1; i <= $prefix_length; i++)); do
        underline=${underline}"▔"
    done
    echo ${underline}
    echo ""

    if [[ "$generate_credential" == "yes" ]]; then
        # Purging old accounts
        result=$($base_dir/aws-pre-req/aws_purge_ca_roles_policies.sh $prefix $generate_minimal_cross_account 2>&1 >/dev/null)
        handle_exception $? $prefix "cross account purge" "$result"
        echo "${CHECK_MARK}  $prefix: cross account purged"

        cred=$(cdp environments list-credentials | jq -r .credentials[].credentialName | grep ${credential})
        if [[ ${credential} == $cred ]]; then
            result=$(cdp environments delete-credential --credential-name ${credential} 2>&1 >/dev/null)
            handle_exception $? $prefix "credential purge" "$result"
            echo "${CHECK_MARK}  $prefix: credential purged"
        fi
    fi

    $base_dir/aws-pre-req/aws_purge_roles_policies.sh $prefix >/dev/null 2>&1
    echo "${CHECK_MARK}  $prefix: existing policies and roles purged"

    aws s3 rb s3://${prefix}-cdp-bucket --force >/dev/null 2>&1
    echo "${CHECK_MARK}  $prefix: bucket purged"

    $base_dir/aws-pre-req/tmp_network/${prefix}_aws_delete_network.sh >/dev/null 2>&1
    echo "${CHECK_MARK}  $prefix: network deleted"

    echo ""
    echo "AWS assets for $prefix deleted!"
    echo ""
    echo "⏱  $(date +%H%Mhrs)"
    echo ""
fi

# 6. Deleting AZ assets
if [[ ${cloud_provider} == "az" ]]; then
    echo "⏱  $(date +%H%Mhrs)"
    echo ""
    echo "Deleting AZ assets for $prefix:"
    underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
    for ((i = 1; i <= $prefix_length; i++)); do
        underline=${underline}"▔"
    done
    echo ${underline}
    echo ""
    ${base_dir}/az-pre-req/az_delete_resource_group.sh $prefix >/dev/null 2>&1
    echo "${CHECK_MARK}  $prefix: resource group content deleted"

    if [[ "$generate_credential" == "yes" ]]; then
        result=$($base_dir/az-pre-req/az_delete_cred_role.sh $prefix 2>&1 >/dev/null)
        handle_exception $? $prefix "credential role purge" "$result"
        echo "${CHECK_MARK}  $prefix: credential role purged"

        result=$($base_dir/az-pre-req/az_delete_rbac_app.sh $prefix 2>&1 >/dev/null)
        handle_exception $? $prefix "credential app purge" "$result"
        echo "${CHECK_MARK}  $prefix: credential app purged"

        cred=$(cdp environments list-credentials | jq -r .credentials[].credentialName | grep ${credential})
        if [[ ${credential} == $cred ]]; then
            result=$(cdp environments delete-credential --credential-name ${credential} 2>&1 >/dev/null)
            handle_exception $? $prefix "credential purge" "$result"
            echo "${CHECK_MARK}  $prefix: credential purged"
        fi
    fi

    echo ""
    echo "Azure assets for $prefix deleted!"
    echo ""
    echo "⏱  $(date +%H%Mhrs)"
    echo ""
fi
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃ All things have been deleted ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
