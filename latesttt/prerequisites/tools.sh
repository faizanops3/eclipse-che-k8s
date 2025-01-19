#!/bin/bash

# helm

# curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
# chmod 700 get_helm.sh
# ./get_helm.sh

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "installing helm..."
sleep 5

# chectl 

bash <(curl -sL  https://che-incubator.github.io/chectl/install.sh)

echo "installing chectl..."
sleep 5




# installing cert-manager

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --wait \
  --create-namespace \
  --namespace cert-manager \
  --set installCRDs=true

