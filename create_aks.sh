#!/bin/sh
# NOTES
# This script requires 2 environment variables should be pre-created befor running on your local machine
# uncomment following exports and update with your values
# You can also change bellow export to fit your requirements
#
#
# export TENANT_ID="your Azure Active Directory ID"
# export SUBSCRIPTION_ID="your Azure subscription where AKS resources will be deployed on"
#
# for common information
export LOCATION="northeurope"
export AKS_RG="cli-aks"

export AKS_NAME="cli-aks"
export AKS_NODE_RG="cli-aks-rg"
export NODE_COUNT="3"
export NODE_POOL="linuxpool"
export NODE_OS_SKU="Ubuntu"

# for networking
export VNET_NAME="cli-vnet"
export VNET_PREFIX="10.80.0.0/16"
export AKS_SUBNET_NAME="cli-aks"
export AKS_SUBNET_PREFIX="10.80.1.0/24"

export PIP_NAME="cli-pip"
export PIP_DNS_NAME="cli-pip-dns"
export APPGW_NAME="cli-appgw"

az login -t $TENANT_ID
az account set -s $SUBSCRIPTION_ID

# set az cli auto confirm
az config set extension.use_dynamic_install=yes_without_prompt

# create Azure resource group
az group create --name $AKS_RG --location $LOCATION

# create Azure Virtual Network aka VNET
az network vnet create -g $AKS_RG -n $VNET_NAME --address-prefix $VNET_PREFIX
AKS_SUBNET_ID=$(az network vnet subnet create -g $AKS_RG --vnet-name $VNET_NAME --name $AKS_SUBNET_NAME --address-prefixes $AKS_SUBNET_PREFIX --query "id" -o tsv | tr -d '\r')

# create Azure Public Ip Address
az network public-ip create -g $AKS_RG -n $PIP_NAME --sku Standard --tier Regional --allocation-method Static --dns-name $PIP_DNS_NAME

# create Azure Application Gateway
vnetBlock1=$(echo $VNET_PREFIX | awk -F . '{print $1}')
vnetBlock2=$(echo $VNET_PREFIX | awk -F . '{print $2}')
az network vnet subnet create -g $AKS_RG --vnet-name $VNET_NAME -n $APPGW_NAME --address-prefixes "${vnetBlock1}.${vnetBlock2}.15.208/28"

az network application-gateway create -g $AKS_RG -n $APPGW_NAME --capacity 2 --sku Standard_v2 --vnet-name $VNET_NAME --subnet $APPGW_NAME --priority 1001 --http-settings-cookie-based-affinity Enabled --public-ip-address $PIP_NAME

# create AKS cluster
az aks create --name $AKS_NAME --resource-group $AKS_RG --kubernetes-version 1.22.11 --node-resource-group $AKS_NODE_RG --nodepool-name $NODE_POOL \
              --os-sku $NODE_OS_SKU --node-count $NODE_COUNT \
              --vnet-subnet-id $AKS_SUBNET_ID \
              --load-balancer-sku Standard --outbound-type loadBalancer --generate-ssh-keys \
              --network-plugin azure --network-policy azure --enable-managed-identity \
              --tags "cluster=$AKS_NAME" --yes