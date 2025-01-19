#!/bin/bash

# Check if the public IP is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <public_ip>"
    exit 1
fi

METALLB_PUBLIC_IP="$1" # Set the public IP from the command line argument

# Update kube-proxy configuration to enable strictARP
echo "Updating kube-proxy configuration..."
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
if [ $? -ne 0 ]; then
    echo "Failed to update kube-proxy configuration. Exiting."
    exit 1
fi
echo "kube-proxy configuration updated successfully."

# Deploy MetalLB
echo "Deploying MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
if [ $? -ne 0 ]; then
    echo "Failed to deploy MetalLB. Exiting."
    exit 1
fi

# Wait for the MetalLB namespace to be ready
echo "Waiting for MetalLB namespace to be ready..."
kubectl wait --for=condition=Available --timeout=120s -n metallb-system deployment controller
if [ $? -ne 0 ]; then
    echo "MetalLB deployment failed. Exiting."
    exit 1
fi
echo "MetalLB deployed successfully."

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

echo "MetalLB configuration completed successfully."

# deploy ingress-nginx
echo "Deploying ingress-nginx..."
sleep 2

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --wait \
  --create-namespace \
  --namespace ingress-nginx




# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0-beta.0/deploy/static/provider/cloud/deploy.yaml

if [ $? -ne 0 ]; then
    echo "Failed to deploy ingress-nginx. Exiting."
    exit 1
fi

# Wait for ingress-nginx deployment to be ready
echo "Waiting for ingress-nginx to be ready..."
kubectl wait --for=condition=Available --timeout=120s -n ingress-nginx deployment ingress-nginx-controller
if [ $? -ne 0 ]; then
    echo "Ingress-nginx deployment failed. Exiting."
    exit 1
fi

# Verify configurations
echo "Ingress-nginx deployed successfully."
echo "MetalLB configured successfully with public IP: $METALLB_PUBLIC_IP"
echo "Retrieving ingress-nginx service details..."
kubectl get svc -n ingress-nginx -w
