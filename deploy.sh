#!/usr/bin/env bash

# Check if tests passed before proceeding
if [ ! -f /workspace/output/test-passed ]; then
    echo "ARM TTK checks failed. Deployment aborted."
    exit 1
fi
echo "ARM TTK checks passed. Proceeding with deployment..."

# Check if Azure CLI is logged in
if ! az account show &> /dev/null; then
    echo "Azure CLI is not logged in. Initiating login using device code..."
    az login --use-device-code
fi

# Usage:
# From root directory, run:
## ./deploy.sh

SCRIPT_DIR=$(pwd)

if [ -z $AZURE_LOCATION ]; then
  AZURE_LOCATION="eastus"
fi

# Generate a unique timestamp
TIMESTAMP=$(date +%Y%m%d%H%M)

if [ -z $RANDOM_NUMBER ]; then
  RANDOM_NUMBER=$(echo $((RANDOM%9999+100)))
fi

# Generate a unique identifier for each run
UNIQUE_ID="${TIMESTAMP}"

# Base names
if [ -z $MANAGED_APP_NAME ]; then
  MANAGED_APP_NAME="my-app-$UNIQUE_ID"
fi

# Resource naming - use fixed resource group name
if [ -z $RESOURCE_GROUP_NAME ]; then
  RESOURCE_GROUP_NAME="marketplace-app"
fi

# Azure Configuration
AZURE_USER_ALIAS=$(az account show --query user.name -otsv |cut -d '@' -f1)
AZURE_USER_ID=$(az ad signed-in-user show --query id -o tsv)

# -- Must be located after Resource Group --
#  -- RANDOM_NUMBER pulled from RG tags --
if [ -z $ITEM_NAME ]; then
  ITEM_NAME="${MANAGED_APP_NAME}${RANDOM_NUMBER}"
fi

if [ -z $STORAGE_ACCOUNT_NAME ]; then
  # Storage account names must be between 3 and 24 characters in length and use numbers and lower-case letters only
  # Format: mktsa<random_number> (total length: 4 + 4 = 8 characters)
  STORAGE_ACCOUNT_NAME="mktsa${RANDOM_NUMBER}"
fi

# Output Configuration
OUTPUT_PATH="$SCRIPT_DIR/output"
SOURCE_TEMPLATE_PATH="$SCRIPT_DIR/src/azuredeploy.json"
TEMPLATE_PATH="$OUTPUT_PATH/mainTemplate.json"
MANAGED_APPLICATION_NAME="${MANAGED_APP_NAME}-${UNIQUE_ID}"
MANAGED_APPLICATION_ZIP_NAME="${MANAGED_APPLICATION_NAME}.zip"
MANAGED_APPLICATION_ZIP_PATH="$OUTPUT_PATH/$MANAGED_APPLICATION_ZIP_NAME"
mkdir -p $OUTPUT_PATH

# Create UI Definition Files
CREATE_UI_DEFINITION_FILE_NAME="createUiDefinition.json"
CREATE_UI_DEFINITION_PATH="$SCRIPT_DIR/ui/$CREATE_UI_DEFINITION_FILE_NAME"
TEMP_CREATE_UI_DEFINITION_PATH="$OUTPUT_PATH/$CREATE_UI_DEFINITION_FILE_NAME"

###############################
## FUNCTIONS                 ##
###############################

function PrintMessage(){
  # Required Argument $1 = Message
  if [ ! -z "$1" ]; then
    echo "$1"
  fi
}

function Verify(){
  # Required Argument $1 = Value to check
  # Required Argument $2 = Value description for error

  if [ -z "$1" ]; then
    echo "$2 is required and was not provided"
    exit 1
  fi
}

function GetExpireDate(){
  if [[ "$(uname)" = Darwin ]]; then
    # We are running on a Mac
    local _expire=$(date -u -v+30M '+%Y-%m-%dT%H:%MZ')
  else
    # For other systems
    local _expire=$(date -u -d "+30 minutes" '+%Y-%m-%dT%H:%MZ')
  fi
  echo $_expire
}

function CreateManagedApplicationZip() {
  # Required Argument $1 = MANAGED_APPLICATION_ZIP_PATH
  # Required Argument $2 = TEMPLATE_PATH
  # Required Argument $3 = CREATE_UI_DEFINITION_PATH

  Verify $1 'CreateManagedApplicationZip-ERROR: Argument (MANAGED_APPLICATION_ZIP_PATH) not received'
  Verify $2 'CreateManagedApplicationZip-ERROR: Argument (TEMPLATE_PATH) not received'
  Verify $3 'CreateManagedApplicationZip-ERROR: Argument (CREATE_UI_DEFINITION_PATH) not received'

  rm -f $1
  zip -j -q $1 $3 ui/viewDefinition.json $2
  echo "  Created zip"
}

function CreateManagedApplication() {
  # Required Argument $1 = STORAGE_ACCOUNT_NAME
  # Required Argument $2 = CONTAINER_NAME
  # Required Argument $3 = MANAGED_APPLICATION_BLOB_NAME
  # Required Argument $4 = MANAGED_APPLICATION_NAME
  # Required Argument $5 = LOCATION
  # Required Argument $6 = RESOURCE_GROUP
  # Required Argument $7 = AZURE_USER_ID

  local _expire=$(GetExpireDate)
  local _sas=$(az storage blob generate-sas --account-name $1 --container-name $2 --name $3 --permissions rcw --expiry $_expire --https-only --only-show-errors --output tsv)

  # Create the managed application definition with Contributor role.
  az managedapp definition create \
    --name $4 \
    --location $5 \
    --resource-group $6 \
    --lock-level ReadOnly \
    --display-name "$4 Name" \
    --description "$4 Description" \
    --authorizations "$7:b24988ac-6180-42a0-ab88-20f7382dd24c" \
    --package-file-uri "https://$1.blob.core.windows.net/$2/$3?$_sas" \
    --only-show-errors \
    --output none

  echo "  Created managed application definition"
}

function CreateResourceGroup() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = LOCATION

  Verify $1 'CreateResourceGroup-ERROR: Argument (RESOURCE_GROUP) not received'
  Verify $2 'CreateResourceGroup-ERROR: Argument (LOCATION) not received'

  local _result=$(az group show --name $1 2>/dev/null)
  if [ "$_result"  == "" ]
    then
      az group create --name $1 \
        --location $2 \
        --tags RANDOM=$RANDOM_NUMBER CONTACT=$AZURE_USER_ALIAS \
        -o none
      echo "  Resource group created"
    else
      echo "  Resource Group $1 already exists."
      RANDOM_NUMBER=$(az group show --name $1 --query tags.RANDOM -otsv)
    fi
}

function CreateStorageAccount() {
  # Required Argument $1 = STORAGE_ACCOUNT_NAME
  # Required Argument $2 = RESOURCE_GROUP
  # Required Argument $3 = LOCATION

  Verify $1 'CreateStorageAccount-ERROR: Argument (STORAGE_ACCOUNT_NAME) not received'
  Verify $2 'CreateStorageAccount-ERROR: Argument (RESOURCE_GROUP) not received'
  Verify $3 'CreateStorageAccount-ERROR: Argument (LOCATION) not received'

  local _storage=$(az storage account show --name $1 --resource-group $2 --query name -o tsv 2>/dev/null)
  if [ -z "$_storage" ]; then
    az storage account create \
      --name $1 \
      --resource-group $2 \
      --location $3 \
      --sku Standard_LRS \
      --kind StorageV2 \
      --tags UNIQUE_ID=$UNIQUE_ID \
      --allow-blob-public-access \
      --query name -o tsv
    echo "  Storage account created"
  else
    echo "  Storage account $1 already exists"
  fi
}

function CreateStorageContainer() {
  # Required Argument $1 = STORAGE_ACCOUNT_NAME
  # Required Argument $2 = CONTAINER_NAME

  az storage container create --name $2 --account-name $1 -o none --only-show-errors
  echo "  Created storage container"
}

function UploadBlobToStorage() {
  # Required Argument $1 = STORAGE_ACCOUNT_NAME
  # Required Argument $2 = CONTAINER_NAME
  # Required Argument $3 = FILE_PATH

  az storage blob upload --account-name $1 --container-name $2 --file $3 --overwrite --only-show-errors --no-progress --output none
  echo "  Uploaded file to storage"
}

function PrepareTemplateFile() {
    # Required Argument $1 = SOURCE_TEMPLATE_PATH
    # Required Argument $2 = TEMPLATE_PATH

    Verify $1 'PrepareTemplateFile-ERROR: Argument (SOURCE_TEMPLATE_PATH) not received'
    Verify $2 'PrepareTemplateFile-ERROR: Argument (TEMPLATE_PATH) not received'

    cp $1 $2
    echo "  Prepared mainTemplate.json"
}

# Move these blocks up before CreateResourceGroup call


if [ -z $ITEM_NAME ]; then
  ITEM_NAME="${MANAGED_APP_NAME}${RANDOM_NUMBER}"
fi

echo "Preparing Template File"
PrepareTemplateFile $SOURCE_TEMPLATE_PATH $TEMPLATE_PATH

echo "Creating Managed Application Zip"
CreateManagedApplicationZip $MANAGED_APPLICATION_ZIP_PATH $TEMPLATE_PATH $CREATE_UI_DEFINITION_PATH

echo "Uploading Managed Application Zip to Storage"


CreateResourceGroup $RESOURCE_GROUP_NAME $AZURE_LOCATION

STORAGE_ACCOUNT_NAME="mktsa${RANDOM_NUMBER}"
CreateStorageAccount $STORAGE_ACCOUNT_NAME $RESOURCE_GROUP_NAME $AZURE_LOCATION
CreateStorageContainer $STORAGE_ACCOUNT_NAME "ama"
UploadBlobToStorage $STORAGE_ACCOUNT_NAME "ama" $MANAGED_APPLICATION_ZIP_PATH

echo "Creating Managed Application Definition"
CreateManagedApplication $STORAGE_ACCOUNT_NAME "ama" $MANAGED_APPLICATION_ZIP_NAME $MANAGED_APPLICATION_NAME $AZURE_LOCATION $RESOURCE_GROUP_NAME $AZURE_USER_ID
