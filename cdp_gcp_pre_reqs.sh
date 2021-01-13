#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi
source $(
    cd $(dirname $0)
    pwd -L
)/common.sh

display_usage() {
    echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Creates GCP pre-requisites

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)"

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

# Parsing arguments
parse_parameters ${1}

# GCP pre-requisites (per env)
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating GCP pre-requisites for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i = 1; i <= $prefix_length; i++)); do
    underline=${underline}"▔"
done
echo ${underline}


# 0. APIs
requiredApis="compute.googleapis.com runtimeconfig.googleapis.com iam.googleapis.com storage.googleapis.com sqladmin.googleapis.com servicenetworking.googleapis.com"
servicesList="$(mktemp)"
gcloud services list > "${servicesList}"
for api in ${requiredApis} ; do
  if ! grep -q ${api} "${servicesList}" ; then
    result=$(gcloud services enable ${api})
    handle_exception $? $prefix "enabling API $api" "$result"
    echo "${CHECK_MARK}  $prefix: enabled API $api"
  fi
done
echo "${ALREADY_DONE}  $prefix: Google APIs for $prefix already enabled"
rm ${servicesList}

# 1. Buckets
if [[ "$($base_dir/gcp-pre-req/gcp_check_if_resource_exists.sh $prefix buckets)" == "no" ]]; then
    result=$($base_dir/gcp-pre-req/gcp_create_buckets.sh $prefix "$region" 2>&1 >/dev/null)
    handle_exception $? $prefix "buckets creation" "$result"
    echo "${CHECK_MARK}  $prefix: buckets for $prefix created"
else
    resource_group=${prefix}-cdp-rg
    echo "${ALREADY_DONE}  $prefix: buckets for $prefix already created"
fi

# 2. IAM
if [[ "$($base_dir/gcp-pre-req/gcp_check_if_resource_exists.sh $prefix iam)" == "no" ]]; then
    result=$($base_dir/gcp-pre-req/gcp_create_iam.sh $prefix 2>&1 >/dev/null)
    handle_exception $? $prefix "iam creation" "$result"
    echo "${CHECK_MARK}  $prefix: iam for $prefix created"
else
    resource_group=${prefix}-cdp-rg
    echo "${ALREADY_DONE}  $prefix: iam $prefix already created"
fi

if [[ "$($base_dir/gcp-pre-req/gcp_check_if_resource_exists.sh $prefix network)" == "no" ]]; then
    if [[ "$create_network" == "yes" ]]; then
        if [[ "$use_priv_ips" == "yes" ]]; then
            echo "⛔  $prefix: one-click does not support private network yet!" >&2
            exit 1
        else
            result=$($base_dir/gcp-pre-req/gcp_create_network.sh $prefix $sg_cidr $region 2>&1 >/dev/null)
            handle_exception $? $prefix "network creation" "$result"
            echo "${CHECK_MARK}  $prefix: network created"
        fi

    fi
else
    echo "${ALREADY_DONE}  $prefix: already network created"
fi

# 5. Credentials
if [[ "$generate_credential" == "yes" ]]; then

    # Purging existing assets
    result=$($base_dir/gcp-pre-req/gcp_delete_service_account.sh $prefix 2>&1 >/dev/null)
    handle_exception $? $prefix "credential service account purge" "$result"
    echo "${CHECK_MARK}  $prefix: credential service account purged"


    cred=$(cdp environments list-credentials | jq -r .credentials[].credentialName | grep ${credential})
    if [[ ${credential} == $cred ]]; then
        result=$(cdp environments delete-credential --credential-name ${credential} 2>&1 >/dev/null)
        handle_exception $? $prefix "credential purge" "$result"
        echo "${CHECK_MARK}  $prefix: credential purged"
    fi

    sleep $sleep_duration

    # Creating account
    result=$($base_dir/gcp-pre-req/gcp_create_service_account.sh $prefix 2>/dev/null)
    handle_exception $? $prefix "credential service account creation" "$result"
    echo "${CHECK_MARK}  $prefix: credential service account created"
    mv ${base_dir}/${prefix}-cdpcrd-sa-gcp-cred.json ${base_dir}/gcp-pre-req/credential_jsons/

    result=$($base_dir/cdp_create_gcp_credential.sh ${credential} ${base_dir}/gcp-pre-req/credential_jsons/${prefix}-cdpcrd-sa-gcp-cred.json 2>&1 >/dev/null)
    handle_exception $? $prefix "credential creation" "$result"
    echo "${CHECK_MARK}  $prefix: new credential created"
fi

echo ""
