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
    $(basename "$0") [--help or -h] <prefix> <region>

Description:
    Creates buckets and subdirectory for CDP environment

Arguments:
    prefix:   prefix for your bucket (root will be <prefix>-cdp-bucket)
    region:   region of your bucket
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
region=$2
bucket=${prefix}-cdp-bucket

location_constraint=""
if [ $region != 'us-east-1' ]
then
  location_constraint="--create-bucket-configuration LocationConstraint=$region"
fi

if [ $(aws s3api head-bucket  --bucket $bucket 2>&1 | wc -l) -gt 0 ] 
then
    aws s3api create-bucket  --bucket $bucket --region $region $location_constraint 
fi

# aws s3api put-object  --bucket $bucket --key $prefix-dl/logs/ 
# aws s3api put-object  --bucket $bucket --key $prefix-dl/ranger/audit/ 
# aws s3api put-object  --bucket $bucket --key $prefix-dl/dataeng/ 
# aws s3api put-object  --bucket $bucket --key $prefix-dl/datasci/ 

aws s3api put-object  --bucket $bucket --key logs/ 
aws s3api put-object  --bucket $bucket --key ranger/audit/ 
aws s3api put-object  --bucket $bucket --key dataeng/ 
aws s3api put-object  --bucket $bucket --key datasci/ 