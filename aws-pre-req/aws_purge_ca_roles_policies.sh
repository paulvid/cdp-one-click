#!/bin/bash 
set -o nounset

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <min_flag>

Description:
    Purges roles and policies for minimal env setup

Arguments:
    prefix:         prefix for your buckets and roles
    min_flag:       if set to yes, will generate the minimal cross account policies (possible values yes or no)
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
min_flag=$2

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





detach_all_policy_per_role ${prefix}-cross-account-role

aws iam delete-role --role-name ${prefix}-cross-account-role



if [[ ${min_flag} == "no" ]]
then
    echo "Deleting Standard Policies"
    aws iam delete-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-cross-account-full-policy 
    echo "Roles and Policies purged!"

else
    echo "minimal policies not supported yet" >&2
    exit 1
fi

