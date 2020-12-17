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
    $(basename "$0") [--help or -h] <prefix> <sg_cidr> <region>

Description:
    Creates network assets for CDP env demployment

Arguments:
    prefix:         prefix of your assets
    sg_cidr:        CIDR to open in your security group
    region:         region of your assets
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage
if [[ (${1:-x} == "--help") || ${1:-x} == "-h" ]]; then
    display_usage
    exit 0
fi

# Check the numbers of arguments
if [ $# -lt 3 ]; then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [ $# -gt 3 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

prefix=$1
cidr=$2
region=$3
project=$(gcloud config get-value project)

# Network
network_name="${prefix}-cdp-network"
gcloud compute networks create ${network_name}  --subnet-mode=custom --bgp-routing-mode=regional

# Subnet
gcloud compute networks subnets create ${network_name}-subnet-1 --network=${network_name} --range=10.1.0.0/19 --region=${region}

# Firewall
gcloud compute firewall-rules create ${network_name}-egress --network ${network_name} --direction egress --action allow --destination-ranges 10.1.0.0/19 --rules tcp,udp,icmp
gcloud compute firewall-rules create ${network_name}-ingress --network ${network_name} --direction ingress --action allow --source-ranges 10.1.0.0/19 --rules tcp,udp,icmp
gcloud compute firewall-rules create ${network_name}-ingress-personal --network ${network_name} --direction ingress --action allow --source-ranges ${cidr} --rules tcp,udp,icmp

# VPC Peering for CloudSQL

gcloud compute addresses create google-managed-services-${network_name} --global --purpose=VPC_PEERING --addresses=10.0.0.0 --prefix-length=19 --network=${network_name}
gcloud services vpc-peerings connect --service=servicenetworking.googleapis.com --ranges=google-managed-services-${network_name} --network=${network_name} --project=${project}
