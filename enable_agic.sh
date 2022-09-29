#!/bin/sh

# get current Application Gateway that created earlier
appgwId=$(az network application-gateway show -n $APPGW_NAME -g $AKS_RG -o tsv --query "id"  | tr -d '\r')

# enable Azure Application Gateway Ingress add-on for AKS cluster
az aks addon enable --name $AKS_NAME --resource-group $AKS_RG --addon ingress-appgw --appgw-id $appgwId

#
#
# After AGIC add-on was installed on your AKS, make sure AKS AAD pod identity works with our pre-created Application Gateway by updating its role assigments 
#
#

# get resource group for AKS nodes
nodeResourceGroup=$(az aks show -n $AKS_NAME -g $AKS_RG --query "nodeResourceGroup" -o tsv | tr -d '\r')

# get AGIC identity
agicIdentity=$(az aks show -n $AKS_NAME -g $AKS_RG --query "addonProfiles.ingressApplicationGateway.identity.resourceId" -o tsv  | tr -d '\r')

loop=1
while [ $loop -le 100 ]
do
    if [[ -z $aksVmssId ]]
    then
        echo "VMSS has not available yet, refresh checking in 1 minute"
        sleep 60
        loop=$(( $loop + 1))
    else
        # get AKS VMSS ID
        aksVmssId=$(az vmss list -g $nodeResourceGroup --query "[0].id" -o tsv  | tr -d '\r')

        # assign AGIC identity to VMSS
        az vmss identity assign --ids $aksVmssId --identities $agicIdentity

        # get AGIC AAD service principal
        agicIdentitySP=$(az aks show -n $AKS_NAME -g $AKS_RG --query "addonProfiles.ingressApplicationGateway.identity.objectId" -o tsv | tr -d '\r')

        # get Application Gateway ID
        appGWId=$(az aks show -n $AKS_NAME -g $AKS_RG --query 'addonProfiles.ingressApplicationGateway.config.applicationGatewayId' -o tsv | tr -d '\r')

        if [[ $agicIdentitySP != "" ]]
        then
            # create role assigment to Application Gateway
            az role assignment create --assignee-object-id $agicIdentitySP --assignee-principal-type ServicePrincipal --role 'Contributor' --scope $appGWId
        else
            exit 1
        fi
    fi
done