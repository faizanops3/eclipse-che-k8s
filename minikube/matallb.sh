#!/bin/bash

# Set variables
METALLB_PUBLIC_IP="<public ip>" # Replace with your desired public IP or IP range

# Update kube-proxy configuration to enable strictARP
echo "Updating kube-proxy configuration..."
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
if [ $? -ne 0 ]; then
    echo "Failed to update kube-proxy configuration. Exiting."
    exit 1
fi

# Deploy MetalLB
echo "Deploying MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
if [ $? -ne 0 ]; then
    echo "Failed to deploy MetalLB. Exiting."
    exit 1
fi

echo "Waiting for MetalLB namespace to be ready..."
until kubectl get ns metallb-system >/dev/null 2>&1; do
    sleep 1
done

# Apply MetalLB configuration with provided public IP
echo "Creating MetalLB configuration with public IP: $METALLB_PUBLIC_IP"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $METALLB_PUBLIC_IP
EOF
if [ $? -ne 0 ]; then
    echo "Failed to apply MetalLB ConfigMap. Exiting."
    exit 1
fi

# Create MetalLB IP Address Pool
echo "Creating MetalLB IPAddressPool..."
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
    - $METALLB_PUBLIC_IP-$METALLB_PUBLIC_IP
EOF
if [ $? -ne 0 ]; then
    echo "Failed to create MetalLB IPAddressPool. Exiting."
    exit 1
fi

# Create MetalLB L2Advertisement
echo "Creating MetalLB L2Advertisement..."
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - first-pool
EOF
if [ $? -ne 0 ]; then
    echo "Failed to create MetalLB L2Advertisement. Exiting."
    exit 1
fi

# # Deploy cert-manager
# echo "Deploying cert-manager..."
# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
# if [ $? -ne 0 ]; then
#     echo "Failed to deploy cert-manager. Exiting."
#     exit 1
# fi

# echo "Waiting for cert-manager to be ready..."
# sleep 10

# Deploy ingress-nginx
echo "Deploying ingress-nginx..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0-beta.0/deploy/static/provider/cloud/deploy.yaml
if [ $? -ne 0 ]; then
    echo "Failed to deploy ingress-nginx. Exiting."
    exit 1
fi

echo "Waiting for ingress-nginx to be ready..."
sleep 10

# Verify MetalLB and ingress-nginx configurations
echo "MetalLB configured successfully with public IP: $METALLB_PUBLIC_IP"
echo "Retrieving ingress-nginx service details..."
kubectl get svc -n ingress-nginx -w



