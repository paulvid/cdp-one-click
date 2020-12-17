#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <sg_cidr>

Description:
    Creates network assets for CDP env demployment

Arguments:
    prefix:         prefix of your assets
    sg_cidr:        CIDR to open in your security group
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

prefix=$1
sg_cidr=$2


# 1. Vnets and subnets
az network vnet create -g $prefix-cdp-rg  --name $prefix-cdp-vnet --address-prefix 10.10.0.0/16

az network vnet subnet create -g $prefix-cdp-rg --vnet-name $prefix-cdp-vnet  -n $prefix-priv-subnet-1 --address-prefixes 10.10.160.0/19
az network vnet subnet create -g $prefix-cdp-rg --vnet-name $prefix-cdp-vnet  -n $prefix-priv-subnet-2 --address-prefixes 10.10.192.0/19
az network vnet subnet create -g $prefix-cdp-rg --vnet-name $prefix-cdp-vnet  -n $prefix-priv-subnet-3 --address-prefixes 10.10.224.0/19

az network vnet subnet update -n $prefix-priv-subnet-1 --vnet-name $prefix-cdp-vnet -g $prefix-cdp-rg --service-endpoints "Microsoft.Sql" "Microsoft.Storage"
az network vnet subnet update -n $prefix-priv-subnet-2 --vnet-name $prefix-cdp-vnet -g $prefix-cdp-rg --service-endpoints "Microsoft.Sql" "Microsoft.Storage"
az network vnet subnet update -n $prefix-priv-subnet-3 --vnet-name $prefix-cdp-vnet -g $prefix-cdp-rg --service-endpoints "Microsoft.Sql" "Microsoft.Storage"


# 2. NSG

az network nsg create -g $prefix-cdp-rg  -n $prefix-knox-nsg  
az network nsg create -g $prefix-cdp-rg  -n $prefix-default-nsg

az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-knox-nsg -n ssh_cidr --priority 102 --source-address-prefixes "$sg_cidr" --destination-address-prefixes '*'  --destination-port-ranges 22 --direction Inbound --access Allow --protocol Tcp --description "Allow SSH to boxes from CIDR."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-knox-nsg -n outbound --priority 107 --source-address-prefixes '*' --destination-address-prefixes '*'  --destination-port-ranges '*' --direction Outbound --access Allow --protocol '*' --description "Allow outbound access."


az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-default-nsg -n outbound --priority 107 --source-address-prefixes '*' --destination-address-prefixes '*'  --destination-port-ranges '*' --direction Outbound --access Allow --protocol '*' --description "Allow outbound access."


