#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 
set -o nounset
BASE_DIR=$(cd $(dirname $0); pwd -L)

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix>

Description:
    Creates minimal set of roles for CDP env

Arguments:
    prefix:   prefix for your roles
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
bucket=${prefix}-cdp-bucket


AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq .Account -r)
DATALAKE_BUCKET=${bucket}
# STORAGE_LOCATION_BASE=${bucket}/${prefix}-dl
# LOGS_LOCATION_BASE=${bucket}/${prefix}-dl/logs

STORAGE_LOCATION_BASE=${bucket}/
LOGS_LOCATION_BASE=${bucket}/
DYNAMODB_TABLE_NAME=${prefix}-cdp-table
IDBROKER_ROLE=${prefix}-idbroker-role
sleep_duration=3


# Creating roles (and sleeping in between)

# IDBROKER
aws iam create-role --role-name ${prefix}-idbroker-role  --assume-role-policy-document file://${BASE_DIR}/access-policies/aws-ec2-role-trust-policy.json
sleep $sleep_duration 

aws iam create-instance-profile --instance-profile-name ${prefix}-idbroker-role
sleep $sleep_duration 

aws iam add-role-to-instance-profile --instance-profile-name ${prefix}-idbroker-role --role-name ${prefix}-idbroker-role
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-idbroker-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-idbroker-assume-role-policy
sleep $sleep_duration 


# DL ADMIN

cat ${BASE_DIR}/access-policies/aws-idbroker-role-trust-policy.json  | sed s/\${AWS_ACCOUNT_ID}/"${AWS_ACCOUNT_ID}"/g | sed s/\${IDBROKER_ROLE}/"${IDBROKER_ROLE}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-role --role-name ${prefix}-datalake-admin-role --assume-role-policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-datalake-admin-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-bucket-policy-s3access
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-datalake-admin-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-dynamodb-policy
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-datalake-admin-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-datalake-admin-policy-s3access
sleep $sleep_duration 


# LOG

aws iam create-role --role-name ${prefix}-log-role --assume-role-policy-document file://${BASE_DIR}/access-policies/aws-ec2-role-trust-policy.json
sleep $sleep_duration 

aws iam create-instance-profile --instance-profile-name ${prefix}-log-role
sleep $sleep_duration 

aws iam add-role-to-instance-profile --instance-profile-name ${prefix}-log-role --role-name ${prefix}-log-role
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-log-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-log-policy-s3access
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-log-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-bucket-policy-s3access
sleep $sleep_duration 


# RANGER AUDIT LOGS

cat ${BASE_DIR}/access-policies/aws-idbroker-role-trust-policy.json | sed s/\${AWS_ACCOUNT_ID}/"${AWS_ACCOUNT_ID}"/g | sed s/\${IDBROKER_ROLE}/"${IDBROKER_ROLE}"/g   > ${BASE_DIR}/${prefix}_tmp
aws iam create-role --role-name ${prefix}-ranger-audit-role --assume-role-policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-ranger-audit-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-bucket-policy-s3access
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-ranger-audit-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-ranger-audit-policy-s3access
sleep $sleep_duration 

aws iam attach-role-policy --role-name ${prefix}-ranger-audit-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/${prefix}-dynamodb-policy
sleep $sleep_duration 


rm ${BASE_DIR}/${prefix}_tmp

echo "Roles Created!"
