#!/bin/sh

# get AKS context and configured helm
az aks get-credentials --name $AKS_NAME --resource-group $AKS_RG
kubectl config use-context $AKS_NAME

# create k8s namespace for argocd

kubectl create namespace argocd
kubectl apply -n argocd -f install.yaml

# run kubectl apply template
kubectl apply -f argocd-server-ingress.yaml
#
#
# Then check your deployed ingress

# grab argocd default password
hostname=$(az network public-ip show -n $PIP_NAME -g $AKS_RG --query ipAddress -o tsv)
password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)



echo "Open your browser with this address: http://${hostname}"
echo "Login into ArgoCD with account: admin/${password}"