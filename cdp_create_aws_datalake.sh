#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <prefix> [--help or -h]

Description:
    Creates a data lake post environment creation

Arguments:
    basedir:        path to the tooling
    prefix:         prefix for your assets
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
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

sleep_duration=1 

# Create groups

AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID

# cdp datalake create-aws-datalake --datalake-name $2-cdp-dl \
#     --environment-name $2-cdp-env \
#     --cloud-provider-configuration instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/$2-idbroker-role",storageBucketLocation="s3a://$2-cdp-bucket/$2-dl"  \
#     --tags key="enddate",value="${END_DATE}" key="project",value="${PROJECT}"

cdp datalake create-aws-datalake --datalake-name $2-cdp-dl \
    --environment-name $2-cdp-env \
    --cloud-provider-configuration instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/$2-idbroker-role",storageBucketLocation="s3a://$2-cdp-bucket"  \
    --tags key="enddate",value="${END_DATE}" key="project",value="${PROJECT}"