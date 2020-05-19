#!/bin/bash 
set -o nounset
BASE_DIR=$(cd $(dirname $0); pwd -L)

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h]  <prefix> <external_id> <ext_acct_id> <min_flag>

Description:
    Creates a cross account role and policy for CDP credential

Arguments:
    prefix:         prefix for your policy/role
    external_id:    your external ID, can be found in register environment screen
    ext_acct_id:    your external account ID, can be found in register environment screen
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
if [  $# -lt 4 ] 
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

prefix=$1
external_id=$2
ext_acct_id=$3
min_flag=$4


AWS_ACCOUNT_ID=$(aws sts get-caller-identity  | jq .Account -r)
sleep_duration=3


# Creating policies (and sleeping in between)
if [[ ${min_flag} == "no" ]]
then
    aws iam create-policy  --policy-name ${prefix}-cross-account-full-policy --policy-document file://${BASE_DIR}/credential-policies/aws-cross-account-full-policy.json  > /dev/null 2>&1
    sleep $sleep_duration 

    cat $BASE_DIR/credential-policies/aws-cross-account-assume-role-policy.json | sed "s/<external_id>/${external_id}/g" | sed "s/<ext_acct_id>/${ext_acct_id}/g" > $BASE_DIR/credential-policies/aws-cross-account-assume-role-policy.tmp
    aws iam create-role  --role-name ${prefix}-cross-account-role --assume-role-policy-document file://$BASE_DIR/credential-policies/aws-cross-account-assume-role-policy.tmp > /dev/null 2>&1
    sleep $sleep_duration 
    rm -f $BASE_DIR/credential-policies/aws-cross-account-assume-role-policy.tmp

    aws iam attach-role-policy  --role-name ${prefix}-cross-account-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-cross-account-full-policy > /dev/null 2>&1
    sleep $sleep_duration 

    
else
    echo "minimal policies not supported yet" >&2
    exit 1
fi