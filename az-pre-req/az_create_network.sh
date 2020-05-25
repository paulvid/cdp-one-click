#!/bin/bash 


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

az network vnet subnet create -g $prefix-cdp-rg --vnet-name $prefix-cdp-vnet  -n $prefix-pub-subnet-1 --address-prefixes 10.10.0.0/24
az network vnet subnet create -g $prefix-cdp-rg --vnet-name $prefix-cdp-vnet  -n $prefix-pub-subnet-2 --address-prefixes 10.10.1.0/24
az network vnet subnet create -g $prefix-cdp-rg --vnet-name $prefix-cdp-vnet  -n $prefix-pub-subnet-3 --address-prefixes 10.10.2.0/24

az network vnet subnet update -n $prefix-pub-subnet-1 --vnet-name $prefix-cdp-vnet -g $prefix-cdp-rg --service-endpoints "Microsoft.Sql" "Microsoft.Storage"
az network vnet subnet update -n $prefix-pub-subnet-2 --vnet-name $prefix-cdp-vnet -g $prefix-cdp-rg --service-endpoints "Microsoft.Sql" "Microsoft.Storage"
az network vnet subnet update -n $prefix-pub-subnet-3 --vnet-name $prefix-cdp-vnet -g $prefix-cdp-rg --service-endpoints "Microsoft.Sql" "Microsoft.Storage"


# 2. NSG

az network nsg create -g $prefix-cdp-rg  -n $prefix-knox-nsg  
az network nsg create -g $prefix-cdp-rg  -n $prefix-default-nsg

az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-knox-nsg -n ssh_cidr --priority 102 --source-address-prefixes "$sg_cidr" --destination-address-prefixes '*'  --destination-port-ranges 22 --direction Inbound --access Allow --protocol Tcp --description "Allow SSH to boxes from CIDR."

az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-knox-nsg -n knox_gateway --priority 103 --source-address-prefixes "$sg_cidr" --destination-address-prefixes '*'  --destination-port-ranges 443 --direction Inbound --access Allow --protocol Tcp --description "Allow control plane knox access."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-knox-nsg -n knox_gateway --priority 104 --source-address-prefixes '52.36.110.208/32' '52.40.165.49/32' '35.166.86.177/32' --destination-address-prefixes '*'  --destination-port-ranges 443 --direction Inbound --access Allow --protocol Tcp --description "Allow knox access from control CIDR."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-knox-nsg -n control_plane --priority 105 --source-address-prefixes "$sg_cidr" --destination-address-prefixes '*'  --destination-port-ranges 9443 --direction Inbound --access Allow --protocol Tcp --description "Allow control plane access."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-knox-nsg -n control_plane --priority 106 --source-address-prefixes '52.36.110.208/32' '52.40.165.49/32' '35.166.86.177/32' --destination-address-prefixes '*'  --destination-port-ranges 9443 --direction Inbound --access Allow --protocol Tcp --description "Allow control plane access from CIDR."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-knox-nsg -n outbound --priority 107 --source-address-prefixes '*' --destination-address-prefixes '*'  --destination-port-ranges '*' --direction Outbound --access Allow --protocol '*' --description "Allow outbound access."


az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-default-nsg -n ssh_cidr --priority 102 --source-address-prefixes "$sg_cidr" --destination-address-prefixes '*'  --destination-port-ranges 22 --direction Inbound --access Allow --protocol Tcp --description "Allow SSH to boxes from CIDR."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-default-nsg -n knox_gateway --priority 103 --source-address-prefixes "$sg_cidr" --destination-address-prefixes '*'  --destination-port-ranges 443 --direction Inbound --access Allow --protocol Tcp --description "Allow control plane knox access."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-default-nsg -n knox_gateway --priority 104 --source-address-prefixes '52.36.110.208/32' '52.40.165.49/32' '35.166.86.177/32' --destination-address-prefixes '*'  --destination-port-ranges 443 --direction Inbound --access Allow --protocol Tcp --description "Allow knox access from control CIDR."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-default-nsg -n control_plane --priority 105 --source-address-prefixes "$sg_cidr" --destination-address-prefixes '*'  --destination-port-ranges 9443 --direction Inbound --access Allow --protocol Tcp --description "Allow control plane access."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-default-nsg -n control_plane --priority 106 --source-address-prefixes '52.36.110.208/32' '52.40.165.49/32' '35.166.86.177/32' --destination-address-prefixes '*'  --destination-port-ranges 9443 --direction Inbound --access Allow --protocol Tcp --description "Allow control plane access from CIDR."
az network nsg rule create -g $prefix-cdp-rg --nsg-name $prefix-default-nsg -n outbound --priority 107 --source-address-prefixes '*' --destination-address-prefixes '*'  --destination-port-ranges '*' --direction Outbound --access Allow --protocol '*' --description "Allow outbound access."


