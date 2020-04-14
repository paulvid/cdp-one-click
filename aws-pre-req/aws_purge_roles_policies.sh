#!/bin/bash 
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix>

Description:
    Purges roles and policies for minimal env setup

Arguments:
    prefix:   prefix for your buckets and roles
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]] 
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

prefix=$1

sleep_duration=3

AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq .Account -r)


detach_all_policy_per_role() {
    role_name=$1
    policy_list=$(aws iam list-attached-role-policies --role-name $role_name | jq -r .AttachedPolicies[].PolicyArn)
    for policy_arn in $(echo $policy_list)
    do
        aws iam detach-role-policy --role-name $role_name --policy-arn $policy_arn
        sleep 2
    done


}







aws iam remove-role-from-instance-profile --instance-profile-name ${prefix}-idbroker-role --role-name ${prefix}-idbroker-role
aws iam remove-role-from-instance-profile --instance-profile-name ${prefix}-log-role --role-name ${prefix}-log-role

aws iam delete-instance-profile --instance-profile-name ${prefix}-idbroker-role 

detach_all_policy_per_role ${prefix}-idbroker-role
aws iam delete-role --role-name ${prefix}-idbroker-role

detach_all_policy_per_role ${prefix}-datalake-admin-role 
aws iam delete-role --role-name ${prefix}-datalake-admin-role 

aws iam delete-instance-profile --instance-profile-name ${prefix}-log-role 
detach_all_policy_per_role ${prefix}-log-role 
aws iam delete-role --role-name ${prefix}-log-role 


detach_all_policy_per_role  ${prefix}-ranger-audit-role
aws iam delete-role --role-name ${prefix}-ranger-audit-role

echo "Deleting Standard Policies"
aws iam delete-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-idbroker-assume-role-policy
aws iam delete-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-log-policy-s3access
aws iam delete-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-ranger-audit-policy-s3access 
aws iam delete-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-datalake-admin-policy-s3access 
aws iam delete-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-bucket-policy-s3access
aws iam delete-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-dynamodb-policy


echo "Roles and Policies purged!"
