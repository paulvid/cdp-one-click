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
    $(basename "$0") [--help or -h] <prefix>

Description:
    Creates Azure resource group

Arguments:
    prefix:         prefix for your resource group (name <prefix>-cdp-rg)
    --help or -h:   displays this help"

}

create_identity()
{
   local IDENTITY="$1"
   local MSI_ID="$2"
   echo "Creating user-assigned MSI for $IDENTITY..."
   local RESULT=$(az identity create -g ${RESOURCE_GROUP_NAME} -n ${IDENTITY})
   local ID=$(echo ${RESULT} | jq -r '.id')
   PRINCIPALID=$(echo ${RESULT} | jq -r '.principalId')
   echo "Created user-assigned MSI with id: $ID and principal id: $PRINCIPALID "
   sleep 60 # Needed to avoid "Principal xxxxxxxxxx does not exist in the directory" error.  
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



SUBSCRIPTION_ID=$(az account show | jq -r .id)
RESOURCE_GROUP_NAME="$1-cdp-rg"
STORAGE_ACCOUNT_NAME="${1//-/}cdpsa"
ASSUMER_IDENTITY="assumerIdentity"
ADMIN_IDENTITY="adminIdentity"
LOGGER_IDENTITY="loggerIdentity"
RANGER_IDENTITY="rangerIdentity"
STORAGE_RESOURCE_GROUP_ID=$(az group list --query "[?name=='$RESOURCE_GROUP_NAME']" | jq -r '.[0].id')

# Create assumer identity
create_identity "$ASSUMER_IDENTITY" "ASSUMER_MSI_ID"
ASSUMER_OBJECTID=$(az identity list -g $RESOURCE_GROUP_NAME|jq '.[]|{"name":.name,"principalId":.principalId}|select(.name | test("assumerIdentity"))|.principalId'| tr -d '"')

# Assign Managed Identity Operator role to the assumerIdentity principal at subscription scope
az role assignment create --assignee $ASSUMER_OBJECTID --role 'f1a07417-d97a-45cb-824c-7a7467783830' --scope "/subscriptions/$SUBSCRIPTION_ID"
# Assign Virtual Machine Contributor role to the assumerIdentity principal at subscription scope
az role assignment create --assignee $ASSUMER_OBJECTID --role '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' --scope "/subscriptions/$SUBSCRIPTION_ID"

# Create admin identity
create_identity "$ADMIN_IDENTITY" "ADMIN_MSI_ID"
ADMIN_OBJECTID=$(az identity list -g $RESOURCE_GROUP_NAME|jq '.[]|{"name":.name,"principalId":.principalId}|select(.name | test("adminIdentity"))|.principalId'| tr -d '"')
# Assign Storage Blob Data Owner role to the dataAccessIdentity principal at logs/data filesystem scope
az role assignment create --assignee $ADMIN_OBJECTID --role 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME/blobServices/default/containers/data"
az role assignment create --assignee $ADMIN_OBJECTID --role 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME/blobServices/default/containers/logs"


# Create logging identity
create_identity "$LOGGER_IDENTITY" "LOGGER_MSI_ID"
LOGGER_OBJECTID=$(az identity list -g $RESOURCE_GROUP_NAME|jq '.[]|{"name":.name,"principalId":.principalId}|select(.name | test("loggerIdentity"))|.principalId'| tr -d '"')
# Assign Storage Blob Data Contributor role to the loggerIdentity principal at logs filesystem scope
az role assignment create --assignee $LOGGER_OBJECTID --role 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME/blobServices/default/containers/logs"

# Create ranger identity
create_identity "$RANGER_IDENTITY" "RANGER_MSI_ID"
RANGER_OBJECTID=$(az identity list -g $RESOURCE_GROUP_NAME|jq '.[]|{"name":.name,"principalId":.principalId}|select(.name | test("rangerIdentity"))|.principalId'| tr -d '"')
# Assign Storage Blob Data Contributor role to the rangerIdentity principal at data filesystem scope
az role assignment create --assignee $RANGER_OBJECTID --role 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME/blobServices/default/containers/data"