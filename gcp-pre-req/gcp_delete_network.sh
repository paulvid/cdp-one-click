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
    Deletes network assets for CDP env demployment

Arguments:
    prefix:         prefix of your assets
    region:         region of your assets
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage
if [[ (${1:-x} == "--help") || ${1:-x} == "-h" ]]; then
    display_usage
    exit 0
fi

# Check the numbers of arguments
if [ $# -lt 2 ]; then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [ $# -gt 2 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

prefix=$1
region=$2
project=$(gcloud config get-value project)

# Network
network_name="${prefix}-cdp-network"
subnet_name="${network_name}-subnet-1"




network_id=$(gcloud compute networks list --format json | jq -r '.[] | select(.name=="'${network_name}'") | .id')
if [[ ${#network_id} -gt 0 ]]
then

    gcloud compute firewall-rules delete ${network_name}-egress --quiet 2>&1 >/dev/null
    gcloud compute firewall-rules delete ${network_name}-ingress --quiet 2>&1 >/dev/null
    gcloud compute firewall-rules delete ${network_name}-ingress-personal --quiet 2>&1 >/dev/null

    gcloud compute networks subnets delete ${subnet_name} --region $region --quiet 2>&1 >/dev/null

    gcloud compute addresses delete google-managed-services-${network_name} --global  --quiet 2>&1 >/dev/null

    gcloud compute networks delete ${network_id} --quiet
fi