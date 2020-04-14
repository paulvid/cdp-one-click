#!/bin/bash 
set -o nounset
BASE_DIR=$(cd $(dirname $0); pwd -L)

display_usage() { 
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> 

Description:
    Creates minimal set of policies for CDP env

Arguments:
    prefix:   prefix for your policies
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
# STORAGE_LOCATION_BASE=${bucket}'\/'${prefix}'\-dl'
# LOGS_LOCATION_BASE=${bucket}'\/'${prefix}'\-dl\/logs'
LOGS_BUCKET=${bucket}
STORAGE_LOCATION_BASE=${bucket}
LOGS_LOCATION_BASE=${bucket}'\/logs'
DYNAMODB_TABLE_NAME=${prefix}'\-cdp\-table'
sleep_duration=3


# Creating policies (and sleeping in between)

aws iam create-policy --policy-name ${prefix}-idbroker-assume-role-policy --policy-document file://${BASE_DIR}/access-policies/aws-idbroker-assume-role-policy.json 
sleep $sleep_duration 

cat ${BASE_DIR}/access-policies/aws-log-policy-s3access.json | sed s/\${LOGS_BUCKET}/"${LOGS_BUCKET}"/g| sed s/\${LOGS_LOCATION_BASE}/"${LOGS_LOCATION_BASE}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-log-policy-s3access --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 

cat ${BASE_DIR}/access-policies/aws-ranger-audit-policy-s3access.json | sed s/\${STORAGE_LOCATION_BASE}/"${STORAGE_LOCATION_BASE}"/g | sed s/\${DATALAKE_BUCKET}/"${DATALAKE_BUCKET}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-ranger-audit-policy-s3access --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 

cat  ${BASE_DIR}/access-policies/aws-datalake-admin-policy-s3access.json | sed s/\${STORAGE_LOCATION_BASE}/"${STORAGE_LOCATION_BASE}"/g  > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-datalake-admin-policy-s3access --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 


cat ${BASE_DIR}/access-policies/aws-bucket-policy-s3access.json  | sed s/\${DATALAKE_BUCKET}/"${DATALAKE_BUCKET}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-bucket-policy-s3access --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration   


cat ${BASE_DIR}/access-policies/aws-dynamodb-policy.json | sed s/\${DYNAMODB_TABLE_NAME}/"${DYNAMODB_TABLE_NAME}"/g > ${BASE_DIR}/${prefix}_tmp
aws iam create-policy --policy-name ${prefix}-dynamodb-policy --policy-document file://${BASE_DIR}/${prefix}_tmp
sleep $sleep_duration 

rm ${BASE_DIR}/${prefix}_tmp

echo "Minimum policies created!"
