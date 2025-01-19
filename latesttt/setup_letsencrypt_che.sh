#!/bin/bash

# Check if required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <your-email@example.com> <your-domain.com>"
    exit 1
fi

EMAIL=$1
DOMAIN=$2

echo "Setting up Let's Encrypt ClusterIssuer for email: $EMAIL"
echo "Creating Certificate for domain: $DOMAIN"

# Create the ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: $EMAIL
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

if [ $? -ne 0 ]; then
    echo "Failed to create ClusterIssuer. Exiting."
    exit 1
fi
echo "ClusterIssuer created successfully."

# Create the namespace for Eclipse Che
echo "Creating namespace: eclipse-che"
kubectl create namespace eclipse-che --dry-run=client -o yaml | kubectl apply -f -

# Create the Certificate for Eclipse Che
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: che-tls
  namespace: eclipse-che
spec:
  secretName: che-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: $DOMAIN
  dnsNames:
  - $DOMAIN
  - "*.$DOMAIN"
EOF

if [ $? -ne 0 ]; then
    echo "Failed to create Certificate. Exiting."
    exit 1
fi
echo "Certificate created successfully."

# Verify the Certificate
echo "Verifying the Certificate creation..."
kubectl get certificate che-tls -n eclipse-che