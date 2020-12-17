#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <resource>

Description:
    Checks if resource exists (returns yes or no)

Arguments:
    prefix:   prefix for your assets
    resource: type of resource to check (in: bucket, network, iam, ca) 
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 2 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 2 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

prefix=$1
resource=$2
response="no"

if [[ "$resource" != "bucket" && "$resource" != "network" && "$resource" != "ca" && "$resource" != "iam" ]]
then
    echo "$resource is not a recognized resource type!"  >&2
    display_usage
    exit 1
fi


if [[ "$resource" == "bucket" ]]
then
    bucket=${prefix}-cdp-bucket
    if [ $(aws s3api head-bucket  --bucket $bucket 2>&1 | wc -l) -eq 0 ] 
    then
        response="yes"
    fi

fi

if [[ "$resource" == "network" ]]
then
    if [ $(aws ec2 describe-vpcs | jq  .Vpcs[].Tags | grep Value | awk -F ":" '{print $2}' | awk -F "\"" '{print $2}' | grep ${prefix}-cdp-vpc | wc -l) -gt 0 ] 
    then
        response="yes"
    fi

fi

if [[ "$resource" == "ca" ]]
then
    role="${prefix}-cross-account-role"
    if [ $(aws iam list-roles | jq -r '.Roles[] | select(.RoleName=="$role")' | wc -l) -gt 0 ] 
    then
        response="yes"
    fi

fi

if [[ "$resource" == "iam" ]]
then
    # 1. Checking policies
    all_policies=$(aws iam list-policies | jq -r .Policies[].PolicyName)

    idbroker_assume_role_policy_name="${prefix}-idbroker-assume-role-policy"
    idbroker_assume_role_policy_exists="no"

    log_policy_s3access_name="${prefix}-log-policy-s3access"
    log_policy_s3access_exists="no"

    ranger_audit_policy_s3access_name="${prefix}-ranger-audit-policy-s3access"
    ranger_audit_policy_s3access_exists="no"

    datalake_admin_policy_s3access_name="${prefix}-datalake-admin-policy-s3access"
    datalake_admin_policy_s3access_exists="no"

    bucket_policy_s3access_name="${prefix}-bucket-policy-s3access"
    bucket_policy_s3access_exists="no"

    dynamodb_policy_name="${prefix}-dynamodb-policy"
    dynamodb_policy_exists="no"

    for policy in $(echo $all_policies)
    do
        if [[ "$policy" == "$idbroker_assume_role_policy_name" ]]
        then
            idbroker_assume_role_policy_exists="yes"
        fi   
        if [[ "$policy" == "$log_policy_s3access_name" ]]
        then
            log_policy_s3access_exists="yes"
        fi   
        if [[ "$policy" == "$ranger_audit_policy_s3access_name" ]]
        then
            ranger_audit_policy_s3access_exists="yes"
        fi   
        if [[ "$policy" == "$datalake_admin_policy_s3access_name" ]]
        then
            datalake_admin_policy_s3access_exists="yes"
        fi   
        if [[ "$policy" == "$bucket_policy_s3access_name" ]]
        then
            bucket_policy_s3access_exists="yes"
        fi   
        if [[ "$policy" == "$dynamodb_policy_name" ]]
        then
            dynamodb_policy_exists="yes"
        fi   
    done

    # 2. Checking roles
    all_roles=$(aws iam list-roles | jq -r .Roles[].RoleName)
    log_role_name="${prefix}-log-role"
    log_role_exists="no"
    ranger_role_name="${prefix}-ranger-audit-role"
    ranger_role_exists="no"
    idbroker_role_name="${prefix}-idbroker-role"
    idbroker_role_exists="no"
    dl_admin_role_name="${prefix}-datalake-admin-role"
    dl_admin_role_exists="no"

    for roles in $(echo $all_roles)
    do
        if [[ "$roles" == "$log_role_name" ]]
        then
            log_role_exists="yes"
        fi   
        if [[ "$roles" == "$ranger_role_name" ]]
        then
            ranger_role_exists="yes"
        fi   
        if [[ "$roles" == "$idbroker_role_name" ]]
        then
            idbroker_role_exists="yes"
        fi   
        if [[ "$roles" == "$dl_admin_role_name" ]]
        then
            dl_admin_role_exists="yes"
        fi   
    done

    if [[ ("$idbroker_assume_role_policy_exists" == "yes") && 
          ("$log_policy_s3access_exists" == "yes") && 
          ("$ranger_audit_policy_s3access_exists" == "yes") && 
          ("$datalake_admin_policy_s3access_exists" == "yes") && 
          ("$bucket_policy_s3access_exists" == "yes") && 
          ("$dynamodb_policy_exists" == "yes") && 
          ("$log_role_exists" == "yes") && 
          ("$ranger_role_exists" == "yes") && 
          ("$idbroker_role_exists" == "yes") && 
          ("$dl_admin_role_exists" == "yes") ]] 
    then
        response="yes"
    fi

fi



echo $response