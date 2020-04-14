#!/bin/bash 
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


error_check() {
    local error=$1
    if [[ ! -z "$error" ]]; then
       if [[ "$error" != "null" ]] && [[ "$error" != *"already exists"* ]]; then
          echo "Error: $error"
          exit 1
       fi
    fi
}
assign_blob_contributor()
{
    local SCOPE="$1"
    echo "Assigning user MSI $PRINCIPALID role Storage Blob Contributor under storage account $STORAGE_ACCOUNT_NAME... " 
    UUID=$(uuidgen)
    local RESULT=$(curl -s -X PUT -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "{\"properties\":{\"roleDefinitionId\":\"$SCOPE/providers/Microsoft.Authorization/roleDefinitions/$AZURE_STORAGE_CONTRIBUTOR_GUID\",\"principalId\":\"$PRINCIPALID\"}}"  "https://management.azure.com$SCOPE/providers/Microsoft.Authorization/roleAssignments/$UUID?api-version=2020-03-01-preview")
    ERROR=$(echo ${RESULT} | jq -r '.error.message')
    error_check "$ERROR"  
}

assign_blob_owner()
{
    local SCOPE="$1"
    echo "Assigning user MSI $PRINCIPALID role Storage Blob Owner under storage account $STORAGE_ACCOUNT_NAME... " 
    UUID=$(uuidgen)
    local RESULT=$(curl -s -X PUT -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "{\"properties\":{\"roleDefinitionId\":\"$SCOPE/providers/Microsoft.Authorization/roleDefinitions/$AZURE_STORAGE_OWNER_GUID\",\"principalId\":\"$PRINCIPALID\"}}"  "https://management.azure.com$SCOPE/providers/Microsoft.Authorization/roleAssignments/$UUID?api-version=2020-03-01-preview")
    ERROR=$(echo ${RESULT} | jq -r '.error.message')
    error_check "$ERROR"  
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
STORAGE_ACCOUNT_NAME="$1cdpsa"
ASSUMER_IDENTITY="assumerIdentity"
ADMIN_IDENTITY="adminIdentity"
LOGGER_IDENTITY="loggerIdentity"
RANGER_IDENTITY="rangerIdentity"
STORAGE_RESOURCE_GROUP_ID=$(az group list --query "[?name=='$RESOURCE_GROUP_NAME']" | jq -r '.[0].id')

# Constants
SCOPE="/subscriptions//$SUBSCRIPTION_ID"

# Create assumer identity
create_identity "$ASSUMER_IDENTITY" "ASSUMER_MSI_ID"
ACCESS_TOKEN=$(az account get-access-token | jq -r '.accessToken')

UUID=$(uuidgen)
RESULT=$(curl -s -X PUT -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "{\"properties\":{\"roleDefinitionId\":\"/$SCOPE/providers/Microsoft.Authorization/roleDefinitions/$AZURE_VM_CONTRIBUTOR_GUID\",\"principalId\":\"$PRINCIPALID\"}}"  "https://management.azure.com/$SCOPE/providers/Microsoft.Authorization/roleAssignments/$UUID?api-version=2020-03-01-preview")
ERROR=$(echo ${RESULT} | jq -r '.error.message')
error_check "$ERROR"
echo "Assigned Virtual Machine Contributor role." 

echo "Assigning Managed Identity Operator role..."
UUID=$(uuidgen)
RESULT=$(curl -s -X PUT -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "{\"properties\":{\"roleDefinitionId\":\"/$SCOPE/providers/Microsoft.Authorization/roleDefinitions/$AZURE_MANAGED_IDENTITY_OPERATOR_GUID\",\"principalId\":\"$PRINCIPALID\"}}"  "https://management.azure.com/$SCOPE/providers/Microsoft.Authorization/roleAssignments/$UUID?api-version=2020-03-01-preview")
ERROR=$(echo ${RESULT} | jq -r '.error.message')
error_check "$ERROR"
echo "Assigned Managed Identity Operator role." 

# Create admin identity
SCOPE="${STORAGE_RESOURCE_GROUP_ID}/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"
create_identity "$ADMIN_IDENTITY" "ADMIN_MSI_ID"
assign_blob_owner "$SCOPE"

# Create logging identity
create_identity "$LOGGER_IDENTITY" "LOGGER_MSI_ID"
assign_blob_contributor "$SCOPE"


create_identity "$RANGER_IDENTITY" "RANGER_MSI_ID"
assign_blob_contributor "$SCOPE"