#!/bin/bash
# ##################################################################################################
# Script to provision an Azure SQL Server database and deploy a Docker image
# to the Azure App Service
# Michael Schletz, 2023
# Usage:
#     Open git bash in your repository folder (context menu -> git bash)
#     Run ./deploy_app.sh
#     If you just want to deploy a new version, answer the following questions:
#         Create resource group:      n
#         Create and deploy app:      n
#         Only deploy app:            y
# Delete azure_secrets.txt to create new credentials and names.
# ##################################################################################################

set -e    # Exit immediately if a command exits with a non-zero status.
YELLOW='\033[0;33m'   # Yellow
NC='\033[0m'          # No Color

if [ ! -f Dockerfile ]; then
    echo "Dockerfile not found. I can't deploy without a Dockerfile :("
fi

START_COLIMA=n
ARCH=$(uname -m)
if [ $ARCH = "aarch64" ] || [ $ARCH = "arm64" ]; then
    read -p "ARM Architecture detected. Should I run colima start? [yn] " START_COLIMA
    if [ $START_COLIMA = y ]; then
        colima start
    fi
fi

# Do we have a secret file from a previous run? We read our variables from that file.
if [ -f azure_secrets.txt ]; then
    read AZ_GROUP DOCKER_IMAGENAME DNS_NAME LOCATION < azure_secrets.txt
else
    read -p "Desired resource group name (lower case letters and numbers only): " AZ_GROUP
    read -p "Desired container image name: " DOCKER_IMAGENAME
    DNS_NAME=${AZ_GROUP}-$(dd if=/dev/random bs=12 count=1 2> /dev/null | base64 | tr '[:upper:]' '[:lower:]' | sed  's/[^a-z0-9]//g')
    LOCATION=northeurope

    echo -e "$AZ_GROUP\t$DOCKER_IMAGENAME\t$DNS_NAME\t$LOCATION" > azure_secrets.txt
    echo -e Secrets generated and written to azure_secrets.txt. ${YELLOW}Ignore azure_secrets.txt in .gitigore! Do not commit this file! ${NC}
fi

# An ACR name cannot have hyphens or other special characters.
ACR_NAME=${DNS_NAME/[^a-z0-9]/}

read -p "$(echo -e "(Re)create resource group $AZ_GROUP in Azure? ${YELLOW}An existing resource group $AZ_GROUP will be deleted.${NC} [yn] ")" CREATE_GROUP
read -p "Create and deploy app service $DNS_NAME in resource group $AZ_GROUP? [yn] " CREATE_APP
if [ $CREATE_APP = n ]; then
    read -n 1 -p "Only deploy app $DNS_NAME in resource group $AZ_GROUP? [yn] " DEPLOY_ONLY_APP
else
    DEPLOY_ONLY_APP=n
fi

if [ $CREATE_GROUP = y ]; then
    echo Create resource group $AZ_GROUP
    set +e
    az group delete --name $AZ_GROUP --yes &> /dev/null
    set -e
    az group create --name $AZ_GROUP --location $LOCATION > /dev/null
fi

if [ $CREATE_APP = y ]; then
    echo Create ACR $ACR_NAME...
    az acr create --name $ACR_NAME --resource-group $AZ_GROUP --sku Basic --admin-enabled true  > /dev/null
    sleep 5  # Wait 5 sec before we can login.
    echo ACR $ACR_NAME created.

    az acr login --name $ACR_NAME  > /dev/null
    docker build -t $ACR_NAME.azurecr.io/$DOCKER_IMAGENAME:v1 .
    docker push $ACR_NAME.azurecr.io/$DOCKER_IMAGENAME:v1  > /dev/null

    ACR_USER=$(az acr credential show --name $ACR_NAME --query username -o tsv)
    ACR_PASS=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)
    az appservice plan create        --name ${DNS_NAME}-plan --resource-group $AZ_GROUP --is-linux --location $LOCATION --sku S1 > /dev/null
    az webapp create                 --name $DNS_NAME        --resource-group $AZ_GROUP --plan ${DNS_NAME}-plan  --deployment-container-image-name $ACR_NAME.azurecr.io/$DOCKER_IMAGENAME:v1 --docker-registry-server-user $ACR_USER --docker-registry-server-password $ACR_PASS  > /dev/null
    
    # GENERATE LOCAL ENVIRONMENTS FOR THE APP SERVICE
    # az webapp config appsettings set --name $DNS_NAME --resource-group $AZ_GROUP --settings "CONNECTIONSTRINGS__DEFAULT"="$DB_CONNECTIONSTRING" "SECRET"="$SECRET" > /dev/null

    az webapp stop  --name $DNS_NAME --resource-group $AZ_GROUP  > /dev/null
    az webapp start --name $DNS_NAME --resource-group $AZ_GROUP  > /dev/null
    echo "App Service https://$DNS_NAME.azurewebsites.net created. It will be available in 1-2 minutes."
fi

if [ $DEPLOY_ONLY_APP = y ]; then
    echo Deploy to $DNS_NAME.azurewebsites.net...

    az webapp stop  --name $DNS_NAME --resource-group $AZ_GROUP  > /dev/null
    az acr login --name $ACR_NAME  > /dev/null
    docker build -t $ACR_NAME.azurecr.io/$DOCKER_IMAGENAME:v1 .
    docker push $ACR_NAME.azurecr.io/$DOCKER_IMAGENAME:v1  > /dev/null
    az webapp start --name $DNS_NAME --resource-group $AZ_GROUP  > /dev/null
    echo "App Service https://$DNS_NAME.azurewebsites.net deployed."
fi

if [ $START_COLIMA = y ]; then
    colima stop
fi
