#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <basedir> <prefix> <scale> (<rds_ha>) [--help or -h]

Description:
    Creates a data lake post environment creation

Arguments:
    basedir:        path to the tooling
    prefix:         prefix for your assets
    scale:          scale of the datalake
    rds_ha:         (optional) flag for rds ha (values 0 or 1)
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 3 ] 
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

if [ $# -eq 4 ] 
then 
    rds_ha=$4
else
    rds_ha=1
fi 

flatten_tags() {
    tags=$1
    flattened_tags=""
    for item in $(echo ${tags} | jq -r '.[] | @base64'); do
        _jq() {
            echo ${item} | base64 --decode | jq -r ${1}
        }
        #echo ${item} | base64 --decode
        key=$(_jq '.key')
        value=$(_jq '.value')
        flattened_tags=$flattened_tags" key=\"$key\",value=\"$value\""
    done
    echo $flattened_tags
}


sleep_duration=1 


AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
owner=$(cdp iam get-user | jq -r .user.email)

if [ ${rds_ha} -eq 1 ] 
then 
    cdp datalake create-aws-datalake --datalake-name $2-cdp-dl \
        --environment-name $2-cdp-env \
        --cloud-provider-configuration instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/$2-idbroker-role",storageBucketLocation="s3a://$2-cdp-bucket"  \
        --scale $3 \
        --tags $(flatten_tags "$TAGS")
else
    cdp datalake create-aws-datalake --datalake-name $2-cdp-dl \
        --environment-name $2-cdp-env \
        --cloud-provider-configuration instanceProfile="arn:aws:iam::$AWS_ACCOUNT_ID:instance-profile/$2-idbroker-role",storageBucketLocation="s3a://$2-cdp-bucket"  \
        --scale $3 \
        --tags $(flatten_tags "$TAGS") \
        --database-availability-type NONE
fi 

